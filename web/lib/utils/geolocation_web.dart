import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<(double, double)?> requestBrowserLocation() async {
  final completer = Completer<(double, double)?>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition pos) {
        if (!completer.isCompleted) {
          completer.complete((pos.coords.latitude, pos.coords.longitude));
        }
      }).toJS,
      ((web.GeolocationPositionError _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS,
      web.PositionOptions(enableHighAccuracy: true, timeout: 12000, maximumAge: 60000),
    );
  } catch (_) {
    return null;
  }
  return completer.future;
}

void savePref(String key, String value) {
  web.window.localStorage.setItem(key, value);
}

String? loadPref(String key) => web.window.localStorage.getItem(key);
