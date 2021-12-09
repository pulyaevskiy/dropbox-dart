import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:quiver/iterables.dart';

const int _kChunkSize = 4 * 1024 * 1024; // 4MB

String dropboxContentHash(List<int> data) {
  var chunks = partition(data, _kChunkSize);

  final chunkHashes = <int>[];
  for (var chunk in chunks) {
    final hash = sha256.convert(chunk).bytes;
    chunkHashes.addAll(hash);
  }

  final finalHash = sha256.convert(chunkHashes).bytes;
  return hex.encode(finalHash);
}
