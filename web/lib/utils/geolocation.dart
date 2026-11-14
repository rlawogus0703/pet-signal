import 'geolocation_stub.dart' if (dart.library.html) 'geolocation_web.dart' as impl;

/// 브라우저 위치 권한을 요청합니다. 거부·미지원이면 null.
Future<(double, double)?> requestBrowserLocation() => impl.requestBrowserLocation();

void savePref(String key, String value) => impl.savePref(key, value);

String? loadPref(String key) => impl.loadPref(key);
