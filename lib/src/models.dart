class DropboxToken {
  /// The access token to be used to call the Dropbox API.
  final String accessToken;

  /// The length of time in seconds that the access token will be valid for.
  ///
  /// Example, "14400" equals to 4 hours
  final int expiresIn;

  /// Will always be `bearer`.
  final String tokenType;

  /// The permission set applied to the token.
  final String? scope;

  /// If the token_access_type was set to offline when calling /oauth2/authorize,
  /// then response will include a refresh token.
  ///
  /// This refresh token is long-lived and won't expire automatically.
  /// It can be stored and re-used multiple times.
  final String? refreshToken;

  DropboxToken({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.scope,
    required this.refreshToken,
  });

  static DropboxToken fromMap(Map<String, dynamic> data) {
    return DropboxToken(
      accessToken: data['access_token'] as String,
      expiresIn: data['expires_in'] as int,
      tokenType: data['token_type'] as String,
      scope: data['scope'] as String?,
      refreshToken: data['refresh_token'] as String?,
    );
  }
}

class DropboxUser {
  /// The user's unique Dropbox ID.
  final String accountId;

  /// Details of a user's name.
  final Name name;

  /// The user's email address. Do not rely on this without checking the
  /// [emailVerified] field. Even then, it's possible that the user has since
  /// lost access to their email.
  final String email;

  /// Whether the user has verified their email address.
  final bool emailVerified;

  /// Whether the user has been disabled.
  final bool disabled;

  /// The language that the user specified. Locale tags will be IETF language
  /// tags.
  final String locale;

  DropboxUser({
    required this.accountId,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.disabled,
    required this.locale,
  });

  static DropboxUser fromMap(Map<String, dynamic> data) {
    return DropboxUser(
      accountId: data['account_id'] as String,
      name: Name.fromMap(data['name'] as Map<String, dynamic>),
      email: data['email'] as String,
      emailVerified: data['email_verified'] as bool,
      disabled: data['disabled'] as bool,
      locale: data['locale'] as String,
    );
  }
}

class Name {
  /// Also known as a first name.
  final String givenName;

  /// Also known as a last name or family name.
  final String surname;

  /// Locale-dependent name. In the US, a person's familiar name is their
  /// given_name, but elsewhere, it could be any combination of a person's
  /// given_name and surname.
  final String familiarName;

  /// A name that can be used directly to represent the name of a user's Dropbox
  /// account.
  final String displayName;

  /// An abbreviated form of the person's name. Their initials in most locales.
  final String abbreviatedName;

  Name({
    required this.givenName,
    required this.surname,
    required this.familiarName,
    required this.displayName,
    required this.abbreviatedName,
  });

  static Name fromMap(Map<String, dynamic> data) {
    return Name(
      givenName: data['given_name'] as String,
      surname: data['surname'] as String,
      familiarName: data['familiar_name'] as String,
      displayName: data['display_name'] as String,
      abbreviatedName: data['abbreviated_name'] as String,
    );
  }
}

class ListFolderResult {
  final List<Metadata> entries;
  final String cursor;
  final bool hasMore;

  ListFolderResult(this.entries, this.cursor, this.hasMore);

  static ListFolderResult fromMap(Map<String, dynamic> data) {
    final entries = data['entries'] as List;
    final cursor = data['cursor'] as String;
    final hasMore = data['has_more'] as bool;
    final metadata =
        entries.map((e) => Metadata.fromMap(e)).toList(growable: false);
    return ListFolderResult(metadata, cursor, hasMore);
  }
}

abstract class Metadata {
  static Metadata fromMap(Map<String, dynamic> data) {
    if (data['.tag'] == 'file') {
      return FileMetadata.fromMap(data);
    } else if (data['.tag'] == 'folder') {
      return FolderMetadata.fromMap(data);
    } else if (data['.tag'] == 'deleted') {
      return DeletedMetadata.fromMap(data);
    } else {
      throw UnsupportedError('Unsupported metadata');
    }
  }
}

class FileMetadata extends Metadata {
  ///  A unique identifier for the file.
  final String id;

  /// The last component of the path (including extension).
  /// This never contains a slash.
  final String name;

  /// For files, this is the modification time set by the desktop client when
  /// the file was added to Dropbox. Since this time is not verified
  /// (the Dropbox server stores whatever the desktop client sends up), this
  /// should only be used for display purposes (such as sorting) and not, for
  /// example, to determine if a file has changed or not.
  ///
  /// Timestamp(format="%Y-%m-%dT%H:%M:%SZ")
  final String clientModified;

  /// The last time the file was modified on Dropbox.
  ///
  /// Timestamp(format="%Y-%m-%dT%H:%M:%SZ")
  final String serverModified;

  /// A unique identifier for the current revision of a file.
  ///
  /// This field is the same rev as elsewhere in the API and can be used to
  /// detect changes and avoid conflicts.
  ///
  /// String(min_length=9, pattern="[0-9a-f]+")
  final String rev;

  /// The file size in bytes.
  final int size;

  /// The lowercased full path in the user's Dropbox.
  ///
  /// This always starts with a slash. This field will be null if the file or
  /// folder is not mounted. This field is optional.
  final String? pathLower;

  /// The cased path to be used for display purposes only.
  ///
  /// In rare instances the casing will not correctly match the user's
  /// filesystem, but this behavior will match the path provided in the Core
  /// API v1, and at least the last path component will have the correct casing.
  /// Changes to only the casing of paths won't be returned by
  /// list_folder/continue. This field will be null if the file or folder is not
  /// mounted. This field is optional.
  final String? pathDisplay;

  /// Additional information if the file is a photo or video.
  ///
  /// This field will not be set on entries returned by list_folder,
  /// list_folder/continue, or get_thumbnail_batch, starting December 2, 2019.
  /// This field is optional.
  final Object? mediaInfo;

  /// Set if this file is a symlink. This field is optional.
  final Object? symlinkInfo;

  /// Set if this file is contained in a shared folder. This field is optional.
  final Object? sharingInfo;

  /// If true, file can be downloaded directly; else the file must be exported.
  /// The default for this field is True.
  final bool isDownloadable;

  /// Information about format this file can be exported to.
  ///
  /// This filed must be set if is_downloadable is set to false.
  /// This field is optional.
  final Object? exportInfo;

  /// Additional information if the file has custom properties with the property
  /// template specified. This field is optional.
  final Object? propertyGroups;

  /// This flag will only be present if include_has_explicit_shared_members is
  /// true in list_folder or get_metadata. If this flag is present, it will be
  /// true if this file has any explicit shared members.
  ///
  /// This is different from sharing_info in that this could be true in the case
  /// where a file has explicit members but is not contained within a shared
  /// folder. This field is optional.
  final bool? hasExplicitSharedMembers;

  /// A hash of the file content. This field can be used to verify data
  /// integrity.
  ///
  /// For more information see our Content hash page:
  /// https://www.dropbox.com/developers/reference/content-hash
  ///
  /// This field is optional.
  final String? contentHash;

  /// If present, the metadata associated with the file's current lock.
  /// This field is optional.
  final Object? fileLockInfo;

  FileMetadata({
    required this.id,
    required this.name,
    required this.clientModified,
    required this.serverModified,
    required this.rev,
    required this.size,
    required this.pathLower,
    required this.pathDisplay,
    required this.mediaInfo,
    required this.symlinkInfo,
    required this.sharingInfo,
    required this.isDownloadable,
    required this.exportInfo,
    required this.propertyGroups,
    required this.hasExplicitSharedMembers,
    required this.contentHash,
    required this.fileLockInfo,
  });

  static FileMetadata fromMap(Map<String, dynamic> data) {
    return FileMetadata(
      id: data['id'] as String,
      name: data['name'] as String,
      clientModified: data['client_modified'] as String,
      serverModified: data['server_modified'] as String,
      rev: data['rev'] as String,
      size: data['size'] as int,
      pathLower: data['path_lower'] as String?,
      pathDisplay: data['path_display'] as String?,
      mediaInfo: null, // TODO
      symlinkInfo: null, // TODO
      sharingInfo: null, // TODO
      isDownloadable: data['is_downloadable'] as bool,
      exportInfo: null, // TODO
      propertyGroups: null, // TODO
      hasExplicitSharedMembers: null, // TODO
      contentHash: data['content_hash'] as String?,
      fileLockInfo: null, // TODO
    );
  }
}

class FolderMetadata extends Metadata {
  ///  A unique identifier for the folder.
  final String id;

  /// The last component of the path (including extension).
  /// This never contains a slash.
  final String name;

  /// The lowercased full path in the user's Dropbox.
  ///
  /// This always starts with a slash. This field will be null if the file or
  /// folder is not mounted. This field is optional.
  final String? pathLower;

  /// The cased path to be used for display purposes only.
  ///
  /// In rare instances the casing will not correctly match the user's
  /// filesystem, but this behavior will match the path provided in the Core
  /// API v1, and at least the last path component will have the correct casing.
  /// Changes to only the casing of paths won't be returned by
  /// list_folder/continue. This field will be null if the file or folder is not
  /// mounted. This field is optional.
  final String? pathDisplay;

  /// Set if the folder is contained in a shared folder or is a shared folder
  /// mount point.
  ///
  /// This field is optional.
  final Object? sharingInfo;

  /// Additional information if the folder has custom properties with the
  /// property template specified.
  ///
  /// Note that only properties associated with user-owned templates, not
  /// team-owned templates, can be attached to folders. This field is optional.
  final Object? propertyGroups;

  FolderMetadata({
    required this.id,
    required this.name,
    required this.pathLower,
    required this.pathDisplay,
    required this.sharingInfo,
    required this.propertyGroups,
  });

  static FolderMetadata fromMap(Map<String, dynamic> data) {
    return FolderMetadata(
      id: data['id'] as String,
      name: data['name'] as String,
      pathLower: data['path_lower'] as String?,
      pathDisplay: data['path_display'] as String?,
      sharingInfo: null, // TODO
      propertyGroups: null, // TODO
    );
  }
}

/// Indicates that there used to be a file or folder at this path, but it no longer exists.
class DeletedMetadata extends Metadata {
  /// The last component of the path (including extension).
  /// This never contains a slash.
  final String name;

  /// The lowercased full path in the user's Dropbox.
  ///
  /// This always starts with a slash. This field will be null if the file or
  /// folder is not mounted. This field is optional.
  final String? pathLower;

  /// The cased path to be used for display purposes only.
  ///
  /// In rare instances the casing will not correctly match the user's
  /// filesystem, but this behavior will match the path provided in the Core
  /// API v1, and at least the last path component will have the correct casing.
  /// Changes to only the casing of paths won't be returned by
  /// list_folder/continue. This field will be null if the file or folder is not
  /// mounted. This field is optional.
  final String? pathDisplay;

  DeletedMetadata({
    required this.name,
    required this.pathLower,
    required this.pathDisplay,
  });

  static DeletedMetadata fromMap(Map<String, dynamic> data) {
    return DeletedMetadata(
      name: data['name'] as String,
      pathLower: data['path_lower'] as String?,
      pathDisplay: data['path_display'] as String?,
    );
  }
}

class DropboxFile {
  final FileMetadata metadata;
  final List<int> content;

  DropboxFile(this.metadata, this.content);
}

class LongpollResult {
  /// Indicates whether new changes are available. If true, call
  /// list_folder/continue to retrieve the changes.
  final bool changes;

  /// If present, backoff for at least this many seconds before calling
  /// list_folder/longpoll again. This field is optional.
  final int? backoff;

  LongpollResult(this.changes, this.backoff);

  static LongpollResult fromMap(Map<String, dynamic> data) {
    return LongpollResult(data['changes'] as bool, data['backoff'] as int?);
  }
}
