import 'dart:typed_data';

/// يقرأ جزءًا من الملف [start, end) دون تحميل الملف كله في الذاكرة (مهم لملفات الفيديو الكبيرة).
typedef RangeReader = Future<Uint8List> Function(int start, int end);

/// صوت مستخرج من فيديو: البيانات وامتداد الملف الناتج (aac أو mp3).
class ExtractedAudio {
  ExtractedAudio(this.bytes, this.ext, this.seconds);
  final Uint8List bytes;
  final String ext;
  final double seconds;
}

class MediaException implements Exception {
  MediaException(this.message);
  final String message;
  @override
  String toString() => message;
}

const kVideoExtensions = ['mp4', 'mov', 'm4v'];

/// يستخرج مسار الصوت من فيديو MP4/MOV كما هو، بدون إعادة ترميز (سريع، ولا يحتاج أي مكتبة).
/// AAC يخرج كملف .aac (ADTS) و MP3 يخرج كملف .mp3. ثم يضغطه العامل إلى m4a بعد الرفع.
Future<ExtractedAudio> extractAudioFromMp4(RangeReader read, int fileLength, {void Function(double)? onProgress}) async {
  final top = await _scanTop(read, fileLength);
  final moov = top.where((b) => b.type == 'moov').firstOrNull;
  if (moov == null) throw MediaException('الملف ليس فيديو mp4 سليمًا');
  final moovData = await read(moov.dataStart, moov.end);
  final tracks = _children(moovData, 0, moovData.length).where((b) => b.type == 'trak');

  _Track? audio;
  for (final t in tracks) {
    final tr = _parseTrack(moovData, t);
    if (tr != null) {
      audio = tr;
      break;
    }
  }
  if (audio == null) throw MediaException('الفيديو ليس فيه صوت');

  // المقاطع (offset, size) لكل عينة صوت
  var samples = audio.samples;
  if (samples.isEmpty) {
    // MP4 مجزأ (fragmented): العينات في صناديق moof
    final trex = _findPath(moovData, 0, moovData.length, ['mvex', 'trex']).where((b) => _u32(moovData, b.dataStart + 4) == audio!.trackId).firstOrNull;
    final defSize = trex == null ? 0 : _u32(moovData, trex.dataStart + 16);
    samples = [];
    for (final m in top.where((b) => b.type == 'moof')) {
      final data = await read(m.start, m.end);
      samples.addAll(_fragmentSamples(data, m.start, audio.trackId, defSize));
    }
  }
  if (samples.isEmpty) throw MediaException('الفيديو ليس فيه صوت');

  final out = BytesBuilder(copy: false);
  final adts = audio.codec == 'aac' ? _AdtsHeader(audio.asc!) : null;
  // نقرأ العينات المتجاورة دفعة واحدة لتقليل عدد مرات القراءة
  var i = 0;
  while (i < samples.length) {
    final start = samples[i].$1;
    var j = i;
    var end = samples[i].$1 + samples[i].$2;
    while (j + 1 < samples.length) {
      final n = samples[j + 1];
      if (n.$1 < end || n.$1 - end > 256 * 1024 || n.$1 + n.$2 - start > 8 * 1024 * 1024) break;
      end = n.$1 + n.$2;
      j++;
    }
    if (end > fileLength) throw MediaException('ملف الفيديو ناقص أو تالف');
    final block = await read(start, end);
    for (var k = i; k <= j; k++) {
      final off = samples[k].$1 - start;
      final len = samples[k].$2;
      if (adts != null) out.add(adts.forFrame(len));
      out.add(Uint8List.sublistView(block, off, off + len));
    }
    i = j + 1;
    onProgress?.call(i / samples.length);
  }
  return ExtractedAudio(out.takeBytes(), audio.codec, audio.seconds);
}

// ---------------------------------------------------------------- صناديق MP4

class _Box {
  _Box(this.type, this.start, this.dataStart, this.end);
  final String type;
  final int start, dataStart, end;
}

int _u16(Uint8List d, int o) => (d[o] << 8) | d[o + 1];
int _u32(Uint8List d, int o) => (d[o] << 24 | d[o + 1] << 16 | d[o + 2] << 8 | d[o + 3]) & 0xFFFFFFFF;
int _u64(Uint8List d, int o) => _u32(d, o) * 0x100000000 + _u32(d, o + 4);
String _type(Uint8List d, int o) => String.fromCharCodes(d.sublist(o, o + 4));

/// صناديق المستوى الأعلى (نقرأ رؤوسها فقط).
Future<List<_Box>> _scanTop(RangeReader read, int length) async {
  final boxes = <_Box>[];
  var o = 0;
  while (o + 8 <= length) {
    final h = await read(o, o + 16 > length ? length : o + 16);
    var size = _u32(h, 0);
    var hdr = 8;
    if (size == 1) {
      if (h.length < 16) break;
      size = _u64(h, 8);
      hdr = 16;
    } else if (size == 0) {
      size = length - o;
    }
    if (size < hdr) break;
    final end = o + size > length ? length : o + size;
    boxes.add(_Box(_type(h, 4), o, o + hdr, end));
    o += size;
  }
  return boxes;
}

List<_Box> _children(Uint8List d, int start, int end) {
  final out = <_Box>[];
  var o = start;
  while (o + 8 <= end) {
    var size = _u32(d, o);
    var hdr = 8;
    if (size == 1) {
      if (o + 16 > end) break;
      size = _u64(d, o + 8);
      hdr = 16;
    } else if (size == 0) {
      size = end - o;
    }
    if (size < hdr || o + size > end) break;
    out.add(_Box(_type(d, o + 4), o, o + hdr, o + size));
    o += size;
  }
  return out;
}

Iterable<_Box> _findPath(Uint8List d, int start, int end, List<String> path) sync* {
  for (final b in _children(d, start, end)) {
    if (b.type != path.first) continue;
    if (path.length == 1) {
      yield b;
    } else {
      yield* _findPath(d, b.dataStart, b.end, path.sublist(1));
    }
  }
}

_Box? _first(Uint8List d, _Box parent, List<String> path) => _findPath(d, parent.dataStart, parent.end, path).firstOrNull;

class _Track {
  _Track(this.trackId, this.codec, this.asc, this.samples, this.seconds);
  final int trackId;
  final String codec; // aac | mp3
  final _Asc? asc;
  final List<(int, int)> samples;
  final double seconds;
}

_Track? _parseTrack(Uint8List d, _Box trak) {
  final hdlr = _first(d, trak, ['mdia', 'hdlr']);
  if (hdlr == null || _type(d, hdlr.dataStart + 8) != 'soun') return null;
  final tkhd = _first(d, trak, ['tkhd']);
  final trackId = tkhd == null ? 0 : _u32(d, tkhd.dataStart + (d[tkhd.dataStart] == 1 ? 20 : 12));

  var seconds = 0.0;
  final mdhd = _first(d, trak, ['mdia', 'mdhd']);
  if (mdhd != null) {
    final v1 = d[mdhd.dataStart] == 1;
    final scale = _u32(d, mdhd.dataStart + (v1 ? 20 : 12));
    final dur = v1 ? _u64(d, mdhd.dataStart + 24) : _u32(d, mdhd.dataStart + 16);
    if (scale > 0) seconds = dur / scale;
  }

  final stbl = _first(d, trak, ['mdia', 'minf', 'stbl']);
  if (stbl == null) return null;
  final stsd = _first(d, stbl, ['stsd']);
  if (stsd == null) return null;
  final entry = _children(d, stsd.dataStart + 8, stsd.end).firstOrNull;
  if (entry == null) return null;

  String codec;
  _Asc? asc;
  if (entry.type == '.mp3') {
    codec = 'mp3';
  } else if (entry.type == 'mp4a') {
    // بعد 8 بايت عامة + 20 بايت للصوت؛ QuickTime الإصدار 1 و 2 يضيفان 16 و 36 بايت
    final ver = _u16(d, entry.dataStart + 8);
    final childStart = entry.dataStart + 28 + (ver == 1 ? 16 : ver == 2 ? 36 : 0);
    final esds = _findDeep(d, childStart, entry.end, 'esds');
    if (esds == null) throw MediaException('صيغة صوت الفيديو غير معروفة');
    final (oti, info) = _parseEsds(d, esds.dataStart + 4, esds.end);
    if (oti == 0x6B || oti == 0x69) {
      codec = 'mp3';
    } else if (oti == 0x40 || oti == 0x66 || oti == 0x67 || oti == 0x68) {
      if (info == null) throw MediaException('صيغة صوت الفيديو غير معروفة');
      codec = 'aac';
      asc = _Asc.parse(info);
    } else {
      throw MediaException('صوت الفيديو بصيغة غير مدعومة. صدّره بصوت AAC أو MP3');
    }
  } else {
    throw MediaException('صوت الفيديو بصيغة غير مدعومة (${entry.type.trim()}). صدّره بصوت AAC');
  }

  return _Track(trackId, codec, asc, _tableSamples(d, stbl), seconds);
}

_Box? _findDeep(Uint8List d, int start, int end, String type) {
  for (final b in _children(d, start, end)) {
    if (b.type == type) return b;
    final inner = _findDeep(d, b.dataStart, b.end, type);
    if (inner != null) return inner;
  }
  return null;
}

/// (objectTypeIndication, AudioSpecificConfig) من صندوق esds.
(int, Uint8List?) _parseEsds(Uint8List d, int o, int end) {
  (int, int, int) desc(int p) {
    final tag = d[p++];
    var len = 0;
    for (var i = 0; i < 4; i++) {
      final b = d[p++];
      len = (len << 7) | (b & 0x7F);
      if (b & 0x80 == 0) break;
    }
    return (tag, p, len);
  }

  var (tag, p, len) = desc(o);
  if (tag != 0x03) return (0, null);
  final esEnd = p + len;
  final flags = d[p + 2];
  p += 3;
  if (flags & 0x80 != 0) p += 2;
  if (flags & 0x40 != 0) p += d[p] + 1;
  if (flags & 0x20 != 0) p += 2;
  while (p < esEnd && p < end) {
    final (t, q, l) = desc(p);
    if (t == 0x04) {
      final oti = d[q];
      var r = q + 13;
      while (r < q + l) {
        final (t2, q2, l2) = desc(r);
        if (t2 == 0x05) return (oti, Uint8List.fromList(d.sublist(q2, q2 + l2)));
        r = q2 + l2;
      }
      return (oti, null);
    }
    p = q + l;
  }
  return (0, null);
}

/// أماكن العينات من جداول stbl (MP4 عادي).
List<(int, int)> _tableSamples(Uint8List d, _Box stbl) {
  final stsz = _first(d, stbl, ['stsz']);
  final stsc = _first(d, stbl, ['stsc']);
  final stco = _first(d, stbl, ['stco']);
  final co64 = _first(d, stbl, ['co64']);
  if (stsz == null || stsc == null || (stco == null && co64 == null)) return [];

  final fixed = _u32(d, stsz.dataStart + 4);
  final count = _u32(d, stsz.dataStart + 8);
  int sizeOf(int i) => fixed != 0 ? fixed : _u32(d, stsz.dataStart + 12 + 4 * i);

  final chunks = <int>[];
  if (co64 != null) {
    final n = _u32(d, co64.dataStart + 4);
    for (var i = 0; i < n; i++) {
      chunks.add(_u64(d, co64.dataStart + 8 + 8 * i));
    }
  } else {
    final n = _u32(d, stco!.dataStart + 4);
    for (var i = 0; i < n; i++) {
      chunks.add(_u32(d, stco.dataStart + 8 + 4 * i));
    }
  }

  final runs = <(int, int)>[]; // (أول chunk بدءًا من 1، عدد العينات في كل chunk)
  final nr = _u32(d, stsc.dataStart + 4);
  for (var i = 0; i < nr; i++) {
    runs.add((_u32(d, stsc.dataStart + 8 + 12 * i), _u32(d, stsc.dataStart + 12 + 12 * i)));
  }

  final out = <(int, int)>[];
  var s = 0;
  for (var c = 0; c < chunks.length && s < count; c++) {
    var per = 0;
    for (final r in runs) {
      if (r.$1 <= c + 1) per = r.$2;
    }
    var off = chunks[c];
    for (var k = 0; k < per && s < count; k++) {
      final sz = sizeOf(s++);
      out.add((off, sz));
      off += sz;
    }
  }
  return out;
}

/// عينات مسار الصوت داخل صندوق moof واحد (MP4 مجزأ).
List<(int, int)> _fragmentSamples(Uint8List d, int moofStart, int trackId, int trexSize) {
  final out = <(int, int)>[];
  for (final traf in _findPath(d, 0, d.length, ['moof', 'traf'])) {
    final tfhd = _first(d, traf, ['tfhd']);
    if (tfhd == null) continue;
    final tf = _u32(d, tfhd.dataStart) & 0xFFFFFF;
    if (_u32(d, tfhd.dataStart + 4) != trackId) continue;
    var p = tfhd.dataStart + 8;
    var base = moofStart;
    if (tf & 0x01 != 0) {
      base = _u64(d, p);
      p += 8;
    }
    if (tf & 0x02 != 0) p += 4;
    if (tf & 0x08 != 0) p += 4;
    var defSize = trexSize;
    if (tf & 0x10 != 0) defSize = _u32(d, p);

    var next = base;
    for (final trun in _children(d, traf.dataStart, traf.end).where((b) => b.type == 'trun')) {
      final fl = _u32(d, trun.dataStart) & 0xFFFFFF;
      final n = _u32(d, trun.dataStart + 4);
      var q = trun.dataStart + 8;
      var off = next;
      if (fl & 0x01 != 0) {
        off = base + _u32(d, q).toSigned(32);
        q += 4;
      }
      if (fl & 0x04 != 0) q += 4;
      for (var i = 0; i < n; i++) {
        if (fl & 0x100 != 0) q += 4;
        var sz = defSize;
        if (fl & 0x200 != 0) {
          sz = _u32(d, q);
          q += 4;
        }
        if (fl & 0x400 != 0) q += 4;
        if (fl & 0x800 != 0) q += 4;
        out.add((off, sz));
        off += sz;
      }
      next = off;
    }
  }
  return out;
}

// ---------------------------------------------------------------- AAC → ADTS

class _Asc {
  _Asc(this.objectType, this.freqIndex, this.channels);
  final int objectType, freqIndex, channels;

  static const _rates = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350];

  static _Asc parse(Uint8List b) {
    var bit = 0;
    int take(int n) {
      var v = 0;
      for (var i = 0; i < n; i++) {
        final byte = bit >> 3;
        final x = byte < b.length ? (b[byte] >> (7 - (bit & 7))) & 1 : 0;
        v = (v << 1) | x;
        bit++;
      }
      return v;
    }

    int objType() {
      final t = take(5);
      return t == 31 ? 32 + take(6) : t;
    }

    int freq() {
      final i = take(4);
      if (i != 15) return i;
      final rate = take(24);
      var best = 4;
      for (var k = 0; k < _rates.length; k++) {
        if ((_rates[k] - rate).abs() < (_rates[best] - rate).abs()) best = k;
      }
      return best;
    }

    var type = objType();
    final fi = freq();
    final ch = take(4);
    if (type == 5 || type == 29) {
      // HE-AAC: نستخدم طبقة AAC الأساسية، والمشغلات تكتشف الإضافة وحدها
      freq();
      type = objType();
    }
    if (type < 1 || type > 4) type = 2;
    return _Asc(type, fi, ch == 0 ? 2 : ch);
  }
}

class _AdtsHeader {
  _AdtsHeader(this.asc);
  final _Asc asc;

  Uint8List forFrame(int payload) {
    final len = payload + 7;
    final profile = asc.objectType - 1;
    return Uint8List.fromList([
      0xFF,
      0xF1, // MPEG-4، بدون CRC
      (profile << 6) | (asc.freqIndex << 2) | ((asc.channels >> 2) & 1),
      ((asc.channels & 3) << 6) | ((len >> 11) & 3),
      (len >> 3) & 0xFF,
      ((len & 7) << 5) | 0x1F,
      0xFC,
    ]);
  }
}
