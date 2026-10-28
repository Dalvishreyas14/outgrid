// Minimal, dependency-free PNG encoder used only by dev tooling to
// preview generator silhouette masks as images (so they can be visually
// sanity-checked before being baked into shipped levels). Not part of
// the shipped app.

import 'dart:typed_data';

int _crc32(List<int> bytes) {
  const poly = 0xEDB88320;
  final table = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (poly ^ (c >> 1)) : (c >> 1);
    }
    return c;
  });
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc = table[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

int _adler32(List<int> bytes) {
  const mod = 65521;
  var a = 1, b = 0;
  for (final byte in bytes) {
    a = (a + byte) % mod;
    b = (b + a) % mod;
  }
  return (b << 16) | a;
}

Uint8List _chunk(String type, List<int> data) {
  final out = BytesBuilder();
  final len = ByteData(4)..setUint32(0, data.length, Endian.big);
  out.add(len.buffer.asUint8List());
  final typeAndData = <int>[...type.codeUnits, ...data];
  out.add(typeAndData.sublist(0, type.length));
  out.add(data);
  final crc = _crc32(typeAndData);
  final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);
  out.add(crcBytes.buffer.asUint8List());
  return out.toBytes();
}

List<int> _zlibStore(List<int> raw) {
  final out = <int>[0x78, 0x01];
  var i = 0;
  const maxBlock = 65535;
  while (i < raw.length) {
    final remaining = raw.length - i;
    final blockLen = remaining > maxBlock ? maxBlock : remaining;
    final isFinal = (i + blockLen) >= raw.length;
    out.add(isFinal ? 1 : 0);
    out.add(blockLen & 0xFF);
    out.add((blockLen >> 8) & 0xFF);
    final nlen = (~blockLen) & 0xFFFF;
    out.add(nlen & 0xFF);
    out.add((nlen >> 8) & 0xFF);
    out.addAll(raw.sublist(i, i + blockLen));
    i += blockLen;
  }
  if (raw.isEmpty) {
    out.addAll([1, 0, 0, 0xFF, 0xFF]);
  }
  final adler = _adler32(raw);
  out.add((adler >> 24) & 0xFF);
  out.add((adler >> 16) & 0xFF);
  out.add((adler >> 8) & 0xFF);
  out.add(adler & 0xFF);
  return out;
}

/// Encodes an RGB (0xRRGGBB per cell) grid as a 24-bit color PNG.
Uint8List encodeRgbPng(List<List<int>> rgbGrid, {int scale = 12}) {
  final rows = rgbGrid.length;
  final cols = rows == 0 ? 0 : rgbGrid[0].length;
  final pixelRows = rows * scale;
  final pixelCols = cols * scale;

  final raw = BytesBuilder();
  for (var py = 0; py < pixelRows; py++) {
    raw.addByte(0);
    final r = py ~/ scale;
    for (var px = 0; px < pixelCols; px++) {
      final c = px ~/ scale;
      final rgb = rgbGrid[r][c];
      raw.addByte((rgb >> 16) & 0xFF);
      raw.addByte((rgb >> 8) & 0xFF);
      raw.addByte(rgb & 0xFF);
    }
  }

  final ihdr = BytesBuilder();
  ihdr.add((ByteData(4)..setUint32(0, pixelCols, Endian.big)).buffer.asUint8List());
  ihdr.add((ByteData(4)..setUint32(0, pixelRows, Endian.big)).buffer.asUint8List());
  ihdr.addByte(8);
  ihdr.addByte(2); // color type: truecolor RGB
  ihdr.addByte(0);
  ihdr.addByte(0);
  ihdr.addByte(0);

  final signature = [137, 80, 78, 71, 13, 10, 26, 10];
  final idatData = _zlibStore(raw.toBytes());
  final out = BytesBuilder();
  out.add(signature);
  out.add(_chunk('IHDR', ihdr.toBytes()));
  out.add(_chunk('IDAT', idatData));
  out.add(_chunk('IEND', const []));
  return out.toBytes();
}

/// Encodes a boolean mask as an 8-bit grayscale PNG: true -> black (0),
/// false -> white (255). [scale] repeats each cell as an NxN pixel block
/// so small logical grids are legible.
Uint8List encodeMaskPng(List<List<bool>> mask, {int scale = 12}) {
  final rows = mask.length;
  final cols = rows == 0 ? 0 : mask[0].length;
  final pixelRows = rows * scale;
  final pixelCols = cols * scale;

  final raw = BytesBuilder();
  for (var py = 0; py < pixelRows; py++) {
    raw.addByte(0); // filter type: none
    final r = py ~/ scale;
    for (var px = 0; px < pixelCols; px++) {
      final c = px ~/ scale;
      raw.addByte(mask[r][c] ? 0 : 255);
    }
  }

  final ihdr = BytesBuilder();
  ihdr.add((ByteData(4)..setUint32(0, pixelCols, Endian.big)).buffer.asUint8List());
  ihdr.add((ByteData(4)..setUint32(0, pixelRows, Endian.big)).buffer.asUint8List());
  ihdr.addByte(8); // bit depth
  ihdr.addByte(0); // color type: grayscale
  ihdr.addByte(0); // compression
  ihdr.addByte(0); // filter
  ihdr.addByte(0); // interlace

  final signature = [137, 80, 78, 71, 13, 10, 26, 10];
  final idatData = _zlibStore(raw.toBytes());

  final out = BytesBuilder();
  out.add(signature);
  out.add(_chunk('IHDR', ihdr.toBytes()));
  out.add(_chunk('IDAT', idatData));
  out.add(_chunk('IEND', const []));
  return out.toBytes();
}
