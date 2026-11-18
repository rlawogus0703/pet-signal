import 'geolocation_stub.dart' if (dart.library.html) 'geolocation_web.dart' as impl;


Future<(double, double)?> requestBrowserLocation() => impl.requestBrowserLocation();

void savePref(String key, String value) => impl.savePref(key, value);

String? loadPref(String key) => impl.loadPref(key);
