import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// 이미지 기반 유사도 — 경량 방식 (색상 히스토그램 + dHash)
///
/// 서버(backend/app/ai/image_embedder.py 의 color-hist+dhash)와 같은 알고리즘입니다.
/// 사진을 80x80 으로 줄이고 가운데 64x64 에서
///  - 앞 64개: R,G,B 4단계 결합 히스토그램 (합 1)
///  - 뒤 64개: 9x8 회색조 격자의 가로 밝기 차이 비트
class ImageFeatures {
  static const method = 'color-hist+dhash';

  /// RGBA 바이트(w*h*4) → 특징 128개
  static List<double> fromRgba(Uint8List rgba, int w, int h) {
    final ox = (w - 64) ~/ 2, oy = (h - 64) ~/ 2;
    final hist = List<double>.filled(64, 0);
    final graySum = List.generate(8, (_) => List<double>.filled(9, 0));
    final grayCnt = List.generate(8, (_) => List<int>.filled(9, 0));
    for (var y = 0; y < 64; y++) {
      final gy = y * 8 ~/ 64;
      for (var x = 0; x < 64; x++) {
        final i = ((oy + y) * w + ox + x) * 4;
        final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
        hist[(r >> 6) * 16 + (g >> 6) * 4 + (b >> 6)] += 1.0;
        final gx = x * 9 ~/ 64;
        graySum[gy][gx] += 0.299 * r + 0.587 * g + 0.114 * b;
        grayCnt[gy][gx] += 1;
      }
    }
    const total = 64.0 * 64.0;
    final out = [for (final v in hist) v / total];
    for (var gy = 0; gy < 8; gy++) {
      final avg = [for (var gx = 0; gx < 9; gx++) graySum[gy][gx] / (grayCnt[gy][gx] == 0 ? 1 : grayCnt[gy][gx])];
      for (var gx = 0; gx < 8; gx++) {
        out.add(avg[gx] > avg[gx + 1] ? 1.0 : 0.0);
      }
    }
    return out;
  }

  /// 히스토그램 교집합 0.7 + dHash 0.3 (우연 수준 0.5 → 0)
  static double similarity(List<double> a, List<double> b) {
    var inter = 0.0;
    for (var i = 0; i < 64; i++) {
      inter += a[i] < b[i] ? a[i] : b[i];
    }
    var same = 0;
    for (var i = 64; i < 128; i++) {
      if (a[i] == b[i]) same++;
    }
    var dh = (same / 64.0 - 0.5) * 2.0;
    if (dh < 0) dh = 0;
    return (0.7 * inter + 0.3 * dh).clamp(0.0, 1.0);
  }

  /// 사진 바이트 → 특징 (디코딩 실패 시 null)
  static Future<List<double>?> fromBytes(Uint8List data) async {
    try {
      final codec = await ui.instantiateImageCodec(data, targetWidth: 80, targetHeight: 80);
      final frame = await codec.getNextFrame();
      final bd = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();
      if (bd == null) return null;
      return fromRgba(bd.buffer.asUint8List(), 80, 80);
    } catch (_) {
      return null;
    }
  }

  static final Map<String, List<double>?> _assetCache = {};

  static Future<List<double>?> fromAsset(String asset) async {
    if (_assetCache.containsKey(asset)) return _assetCache[asset];
    List<double>? f;
    try {
      final bd = await rootBundle.load(asset);
      f = await fromBytes(bd.buffer.asUint8List());
    } catch (_) {
      f = null;
    }
    return _assetCache[asset] = f;
  }
}
