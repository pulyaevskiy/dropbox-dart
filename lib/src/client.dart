import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';

import 'models.dart';

final Logger _l = Logger('DropboxClient');

extension _MapUtils<K, V> on Map<K, V> {
  void putIfNotNull(K key, V value) {
    if (value != null) {
      this[key] = value;
    }
  }
}

class DropboxError {
  final int statusCode;
  final String? errorSummary;
  final String? errorTag;

  DropboxError({
    required this.statusCode,
    required this.errorSummary,
    required this.errorTag,
  });

  static DropboxError fromResponse(Response response) {
    assert(response.statusCode >= 400);
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DropboxError(
        statusCode: response.statusCode,
        errorSummary: data['error_summary'],
        errorTag: data['error']['.tag'],
      );
    } catch (error, stackTrace) {
      _l.warning(
          'Cannot parse error response: "${response.body}"', error, stackTrace);
      return DropboxError(
          statusCode: response.statusCode, errorSummary: null, errorTag: null);
    }
  }

  static Future<DropboxError> fromStreamedResponse(
      StreamedResponse response) async {
    assert(response.statusCode >= 400);

    final body = await response.stream.bytesToString();
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return DropboxError(
        statusCode: response.statusCode,
        errorSummary: data['error_summary'],
        errorTag: data['error']['.tag'],
      );
    } catch (error, stackTrace) {
      _l.warning('Cannot parse error response: "$body"', error, stackTrace);
      return DropboxError(
          statusCode: response.statusCode, errorSummary: null, errorTag: null);
    }
  }
}

/// Your intent when writing a file to some path.
///
/// This is used to determine what constitutes a conflict and what the
/// autorename strategy is.
///
/// In some situations, the conflict behavior is identical:
/// (a) If the target path doesn't refer to anything, the file is always
///     written; no conflict.
/// (b) If the target path refers to a folder, it's always a conflict.
/// (c) If the target path refers to a file with identical contents, nothing
///     gets written; no conflict.
///
/// The conflict checking differs in the case where there's a file at the
/// target path with contents different from the contents you're trying to
/// write.
class WriteMode {
  /// Do not overwrite an existing file if there is a conflict.
  ///
  /// The autorename strategy is to append a number to the file name.
  /// For example, "document.txt" might become "document (2).txt".
  static const WriteMode add = WriteMode._('add');

  /// Always overwrite the existing file.
  ///
  /// The autorename strategy is the same as it is for add.
  static const WriteMode overwrite = WriteMode._('overwrite');

  ///  Overwrite if the given "rev" matches the existing file's "rev".
  ///
  ///  The autorename strategy is to append the string "conflicted copy" to the
  ///  file name. For example, "document.txt" might become
  ///  "document (conflicted copy).txt" or
  ///  "document (Panda's conflicted copy).txt".
  static WriteMode update(String rev) => WriteMode._('update', rev);

  const WriteMode._(this.mode, [this.rev]);

  final String mode;
  final String? rev;

  dynamic toJson() {
    if (mode == 'update') {
      return {'.tag': 'update', 'update': rev};
    }
    return mode; // for 'add' and 'overwrite'
  }
}

/// A shared link to list the contents of.
class SharedLink {
  /// Shared link url.
  final String url;

  /// Password for the shared link. This field is optional.
  final String? password;

  SharedLink({required this.url, this.password});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'url': url};
    json.putIfNotNull('password', password);
    return json;
  }
}

typedef DropboxRefreshAccessTokenCallback = Future<String> Function();

class DropboxClient {
  String get accessToken => _accessToken;
  String _accessToken;
  final DropboxRefreshAccessTokenCallback onRefreshAccessToken;

  DropboxClient(String accessToken, this.onRefreshAccessToken)
      : _accessToken = accessToken;

  static Future<DropboxToken> getAuthToken({
    required String authorizationCode,
    required String codeVerifier,
    required String redirectUrl,
    required String clientId,
    required String clientSecret,
  }) async {
    final client = Client();
    final credentials = base64.encode(utf8.encode('$clientId:$clientSecret'));
    final headers = <String, String>{
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final body = {
      'code': authorizationCode,
      'code_verifier': codeVerifier,
      'grant_type': 'authorization_code',
      'redirect_uri': redirectUrl,
    };

    final response = await client.post(
      Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      headers: headers,
      body: body,
    );

    if (response.statusCode >= 400) {
      throw DropboxError.fromResponse(response);
    }

    return DropboxToken.fromMap(jsonDecode(response.body));
  }

  static Future<DropboxToken> getAccessToken({
    required String clientId,
    required String clientSecret,
    required String refreshToken,
  }) async {
    final client = Client();
    final credentials = base64.encode(utf8.encode('$clientId:$clientSecret'));
    final headers = <String, String>{
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    final body = {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    };

    final response = await client.post(
      Uri.parse('https://api.dropboxapi.com/oauth2/token'),
      headers: headers,
      body: body,
    );

    if (response.statusCode >= 400) {
      throw DropboxError.fromResponse(response);
    }

    return DropboxToken.fromMap(jsonDecode(response.body));
  }

  /// Get information about the current user's account.
  Future<DropboxUser> getCurrentUser() async {
    final response = await _httpPost(
        'https://api.dropboxapi.com/2/users/get_current_account');

    return DropboxUser.fromMap(jsonDecode(response.body));
  }

  /// Download a file from a user's Dropbox.
  Future<DropboxFile> download({
    /// The path of the file to download.
    required String path,
  }) async {
    final response = await _httpSend(
        'POST', 'https://content.dropboxapi.com/2/files/download', (request) {
      final args = <String, dynamic>{'path': path};
      request.headers['Dropbox-API-Arg'] = jsonEncode(args);
    });

    final data = response.headers['Dropbox-API-Result'] as String;
    final content = await response.stream.toBytes();

    final metadata = FileMetadata.fromMap(jsonDecode(data));
    return DropboxFile(metadata, content);
  }

  /// Create a new file with the contents provided in the request.
  ///
  /// Do not use this to upload a file larger than 150 MB. Instead, create an
  /// upload session with upload_session/start.
  ///
  /// Calls to this endpoint will count as data transport calls for any
  /// Dropbox Business teams with a limit on the number of data transport calls
  /// allowed per month. For more information, see the Data transport limit
  /// page.
  Future<FileMetadata> upload({
    /// Path in the user's Dropbox to save the file.
    required String path,

    /// File to upload. If this is set then [data] must be null.
    File? file,

    /// Data to upload. If this is set then [file] must be null.
    List<int>? data,

    /// Selects what to do if the file already exists. The default for this union is add.
    WriteMode mode = WriteMode.add,

    /// If there's a conflict, as determined by mode, have the Dropbox server
    /// try to autorename the file to avoid conflict.
    ///
    /// The default for this field is false.
    bool autorename = false,

    /// The value to store as the client_modified timestamp.
    ///
    /// Dropbox automatically records the time at which the file was written to
    /// the Dropbox servers. It can also record an additional timestamp,
    /// provided by Dropbox desktop clients, mobile clients, and API apps of
    /// when the file was actually created or modified. This field is optional.
    DateTime? clientModified,

    /// Normally, users are made aware of any file modifications in their
    /// Dropbox account via notifications in the client software.
    ///
    /// If true, this tells the clients that this modification shouldn't result
    /// in a user notification. The default for this field is false.
    bool mute = false,

    /// List of custom properties to add to file. This field is optional.
    List? propertyGroups,

    /// Be more strict about how each WriteMode detects conflict.
    ///
    /// For example, always return a conflict error when mode = WriteMode.update
    /// and the given "rev" doesn't match the existing file's "rev", even if the
    /// existing file has been deleted.
    ///
    /// This also forces a conflict even when the target path refers to a file
    /// with identical contents. The default for this field is false.
    bool strictConflict = false,
  }) async {
    final response =
        await _httpSend('POST', 'https://content.dropboxapi.com/2/files/upload',
            (request) async {
      final args = <String, dynamic>{
        'path': path,
        'mode': mode,
      };
      final clientModifiedAsString = clientModified?.toUtc().toIso8601String();
      args
        ..putIfNotNull('autorename', autorename)
        ..putIfNotNull('client_modified', clientModifiedAsString)
        ..putIfNotNull('mute', mute)
        ..putIfNotNull(
            'property_groups', null) // TODO: implement property_groups
        ..putIfNotNull('strict_conflict', strictConflict);

      request.headers['Dropbox-API-Arg'] = jsonEncode(args);
      request.headers['Content-Type'] = 'application/octet-stream';

      if (file != null) {
        request.contentLength = await file.length();

        file.openRead().listen(
              request.sink.add,
              onDone: request.sink.close,
              onError: request.sink.addError,
            );
      } else if (data != null) {
        request.contentLength = data.length;
        request.sink.add(data);
        request.sink.close();
      } else {
        throw ArgumentError('Either file or data must be provided.');
      }
    });

    final body = await response.stream.bytesToString();

    return FileMetadata.fromMap(jsonDecode(body));
  }

  /// Starts returning the contents of a folder.
  ///
  /// If the result's ListFolderResult.has_more field is true, call
  /// list_folder/continue with the returned ListFolderResult.cursor to retrieve
  /// more entries.
  Future<ListFolderResult> listFolder({
    /// A unique identifier for the file.
    required String path,

    /// If true, the list folder operation will be applied recursively to all
    /// subfolders and the response will contain contents of all subfolders.
    /// The default for this field is false.
    bool recursive = false,

    /// If true, the results will include entries for files and folders that
    /// used to exist but were deleted. The default for this field is false.
    bool includeDeleted = false,

    /// If true, the results will include a flag for each file indicating
    /// whether or not that file has any explicit members.
    /// The default for this field is false.
    bool includeHasExplicitSharedMembers = false,

    /// If true, the results will include entries under mounted folders which
    /// includes app folder, shared folder and team folder.
    ///
    /// The default for this field is true.
    bool includeMountedFolders = true,

    /// The maximum number of results to return per request.
    ///
    /// Note: This is an approximate number and there can be slightly more
    /// entries returned in some cases. This field is optional.
    int? limit,

    /// A shared link to list the contents of.
    ///
    /// If the link is password-protected, the password must be provided.
    /// If this field is present, ListFolderArg.path will be relative to root
    /// of the shared link. Only non-recursive mode is supported for shared
    /// link. This field is optional.
    SharedLink? sharedLink,

    /// If set to a valid list of template IDs, FileMetadata.property_groups is
    /// set if there exists property data associated with the file and each of
    /// the listed templates. This field is optional.
    dynamic includePropertyGroups,

    /// If true, include files that are not downloadable, i.e. Google Docs.
    ///
    /// The default for this field is true.
    bool includeNonDownloadableFiles = true,
  }) async {
    final args = <String, dynamic>{'path': path};
    args
      ..putIfNotNull('recursive', recursive)
      ..putIfNotNull('include_deleted', includeDeleted)
      ..putIfNotNull('include_has_explicit_shared_members',
          includeHasExplicitSharedMembers)
      ..putIfNotNull('include_mounted_folders', includeMountedFolders)
      ..putIfNotNull('limit', limit)
      ..putIfNotNull('shared_link', sharedLink)
      ..putIfNotNull('include_property_groups', null) // TODO: implement
      ..putIfNotNull(
          'include_non_downloadable_files', includeNonDownloadableFiles);

    final response = await _httpPost(
      'https://api.dropboxapi.com/2/files/list_folder',
      body: jsonEncode(args),
    );

    if (response.statusCode >= 400) {
      throw DropboxError.fromResponse(response);
    }

    return ListFolderResult.fromMap(jsonDecode(response.body));
  }

  Future<ListFolderResult> listFolderContinue(String cursor) async {
    final args = <String, dynamic>{'cursor': cursor};
    final response = await _httpPost(
      'https://api.dropboxapi.com/2/files/list_folder/continue',
      body: jsonEncode(args),
    );

    // TODO: https://developers.dropbox.com/detecting-changes-guide
    // Specifies that when cursor has expired the continue endpoint returns
    // 409
    if (response.statusCode >= 400) {
      throw DropboxError.fromResponse(response);
    }

    return ListFolderResult.fromMap(jsonDecode(response.body));
  }

  /// A longpoll endpoint to wait for changes on an account. In conjunction
  /// with list_folder/continue, this call gives you a low-latency way to
  /// monitor an account for file changes.
  /// The connection will block until there are changes available or a timeout
  /// occurs. This endpoint is useful mostly for client-side apps.
  Future<LongpollResult> listFolderLongpoll(String cursor, int timeout) async {
    final args = <String, dynamic>{'cursor': cursor, 'timeout': timeout};

    // TODO: https://developers.dropbox.com/detecting-changes-guide
    // Specifies that when cursor has expired the continue endpoint returns
    // 409
    final response = await _httpPost(
      'https://notify.dropboxapi.com/2/files/list_folder/longpoll',
      body: jsonEncode(args),
    );

    return LongpollResult.fromMap(jsonDecode(response.body));
  }

  Future<Response> _httpPost(String url, {String? body}) async {
    final client = Client();
    final headers = <String, String>{'Authorization': 'Bearer $accessToken'};

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final response = await client.post(
      Uri.parse(url),
      body: body,
      headers: headers,
    );

    if (response.statusCode >= 200 && response.statusCode < 400) {
      return response;
    }

    final error = DropboxError.fromResponse(response);
    if (error.statusCode == 401 && error.errorTag == 'expired_access_token') {
      // need to get a new accessToken and retry
      _accessToken = await onRefreshAccessToken();
      headers['Authorization'] = _accessToken;
      return await client.post(
        Uri.parse(url),
        body: body,
        headers: headers,
      );
    }
    throw error;
  }

  Future<StreamedResponse> _httpSend(String method, String url,
      FutureOr<void> Function(StreamedRequest request) handler) async {
    final request = StreamedRequest(method, Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $accessToken';

    await handler(request);

    final client = Client();
    final response = await client.send(request);

    if (response.statusCode >= 200 && response.statusCode < 400) {
      return response;
    }

    final error = await DropboxError.fromStreamedResponse(response);
    if (error.statusCode == 401 && error.errorTag == 'expired_access_token') {
      _accessToken = await onRefreshAccessToken();

      final request = StreamedRequest(method, Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $accessToken';

      await handler(request);

      return await client.send(request);
    }
    throw error;
  }
}
