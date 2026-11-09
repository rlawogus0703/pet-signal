import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/user.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  AuthSession? _session;

  @override
  AuthSession? get current => _session;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<AuthSession> _parseAuth(http.Response res) async {
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw StateError('인증 실패: ${res.statusCode} ${res.body}');
    }
    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final user = AppUser.fromJson(map['user'] as Map<String, dynamic>);
    _session = AuthSession(
      accessToken: map['access_token'] as String,
      user: user,
    );
    return _session!;
  }

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    final res = await _client.post(
      _u('/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        'phone': phone,
      }),
    );
    return _parseAuth(res);
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final res = await _client.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseAuth(res);
  }

  @override
  Future<AppUser> me() async {
    final s = _session;
    if (s == null) throw StateError('로그인이 필요합니다');
    final res = await _client.get(
      _u('/auth/me'),
      headers: {'Authorization': 'Bearer ${s.accessToken}'},
    );
    if (res.statusCode != 200) throw StateError('me failed');
    return AppUser.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    _session = null;
  }

  String? get token => _session?.accessToken;
}
