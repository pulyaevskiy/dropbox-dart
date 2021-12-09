import 'dart:convert';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:dropbox/dropbox.dart';
import 'package:test/test.dart';

void main() {
  dotenv.load('test/.env');

  group('DropboxClient', () {
    test('smoke test', () async {
      final token = dotenv.env['DROPBOX_TEST_ACCESS_TOKEN'] as String;
      final client = DropboxClient(token);
      final result = await client.listFolder(path: '');

      expect(result.entries, hasLength(0));

      final data = utf8.encode('test');
      final metadata = await client.upload(
        path: '/smoke.test',
        data: data,
        mute: true,
        strictConflict: true,
      );
      expect(metadata.id, isNotNull);
    });
  });
}
