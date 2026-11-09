import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/api_auth_repository.dart';
import '../data/api_repository.dart';
import '../data/auth_repository.dart';
import '../data/mock_auth_repository.dart';
import '../data/mock_repository.dart';
import '../data/repository.dart';
import '../models/lost_dog.dart';
import '../models/user.dart';

/// 내가 등록한 실종견 (화면 표시용 로컬 정보 포함)
class MyDog {
  MyDog({required this.dog, required this.name, this.photoBytes, this.photoAsset});
  final LostDog dog;
  final String name;
  final Uint8List? photoBytes;
  final String? photoAsset;
}

/// 앱 전역 상태: 모드(Mock/API), 인증, 내 실종견, 탭, 알림 수
class AppState extends ChangeNotifier {
  AppState() {
    _build();
  }

  bool useApi = false;
  String apiBaseUrl = 'http://127.0.0.1:8000';

  late AuthRepository auth;
  late PetSignalRepository repo;

  int tab = 0;
  int unread = 0;
  String? selectedDogId;
  final Map<String, List<MyDog>> _dogs = {};

  void _build() {
    if (useApi) {
      final a = ApiAuthRepository(baseUrl: apiBaseUrl);
      auth = a;
      repo = ApiRepository(baseUrl: apiBaseUrl, auth: a);
    } else {
      auth = MockAuthRepository();
      repo = MockRepository();
    }
  }

  AppUser? get user => auth.current?.user;
  bool get loggedIn => auth.current != null;
  String get displayName {
    final u = user;
    if (u == null) return '';
    return u.name.isEmpty ? u.email.split('@').first : u.name;
  }

  String get _key => '${useApi ? 'api' : 'mock'}:${user?.email ?? ''}';
  List<MyDog> get myDogs => List.unmodifiable(_dogs[_key] ?? const []);

  MyDog? get selectedDog {
    final list = myDogs;
    if (list.isEmpty) return null;
    return list.firstWhere((d) => d.dog.id == selectedDogId, orElse: () => list.first);
  }

  void setMode({required bool api, String? baseUrl}) {
    useApi = api;
    if (baseUrl != null && baseUrl.trim().isNotEmpty) apiBaseUrl = baseUrl.trim();
    _build();
    selectedDogId = null;
    unread = 0;
    notifyListeners();
  }

  void goTab(int i) {
    tab = i;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await auth.login(email: email, password: password);
    await refreshUnread();
    notifyListeners();
  }

  Future<void> signup({required String email, required String password, required String name, String? phone}) async {
    await auth.signup(email: email, password: password, name: name, phone: phone);
    notifyListeners();
  }

  /// 데모 계정으로 바로 시작 (Mock: 미리 생성 / API: 없으면 가입)
  Future<void> demoLogin() async {
    const email = MockAuthRepository.demoEmail;
    const pw = MockAuthRepository.demoPassword;
    try {
      await auth.login(email: email, password: pw);
    } catch (_) {
      await auth.signup(email: email, password: pw, name: '김재현');
    }
    await refreshUnread();
    notifyListeners();
  }

  Future<void> logout() async {
    await auth.logout();
    tab = 0;
    unread = 0;
    selectedDogId = null;
    notifyListeners();
  }

  Future<LostDog> registerDog({
    required String name,
    Uint8List? photoBytes,
    String? photoAsset,
    required String breed,
    required String color,
    required String features,
    String? age,
    required DateTime lostDate,
    required double lostLat,
    required double lostLng,
    required String lostAddress,
  }) async {
    final dog = await repo.registerLostDog(
      breed: breed,
      color: color,
      features: features,
      age: age,
      lostDate: lostDate,
      lostLat: lostLat,
      lostLng: lostLng,
      lostAddress: lostAddress,
    );
    final list = _dogs.putIfAbsent(_key, () => []);
    list.insert(0, MyDog(dog: dog, name: name, photoBytes: photoBytes, photoAsset: photoAsset));
    selectedDogId = dog.id;
    await refreshUnread();
    notifyListeners();
    return dog;
  }

  void removeDog(String id) {
    _dogs[_key]?.removeWhere((d) => d.dog.id == id);
    if (selectedDogId == id) selectedDogId = null;
    refreshUnread();
    notifyListeners();
  }

  void selectDog(String id) {
    selectedDogId = id;
    notifyListeners();
  }

  MyDog? dogById(String id) {
    for (final d in myDogs) {
      if (d.dog.id == id) return d;
    }
    return null;
  }

  Future<void> refreshUnread() async {
    var n = 0;
    for (final d in myDogs) {
      try {
        final items = await repo.getNotifications(d.dog.id);
        n += items.where((e) => !e.read).length;
      } catch (_) {}
    }
    unread = n;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
