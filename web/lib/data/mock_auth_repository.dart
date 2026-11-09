import 'package:uuid/uuid.dart';

import '../models/user.dart';
import 'auth_repository.dart';

/// Mock 모드: 메모리에 회원 저장 (백엔드 없이 시연)
class MockAuthRepository implements AuthRepository {
  final _uuid = const Uuid();
  final Map<String, _Stored> _usersByEmail = {};
  AuthSession? _session;

  /// 시연용 데모 계정
  static const demoEmail = 'demo@petsignal.kr';
  static const demoPassword = 'demo1234';

  MockAuthRepository() {
    final demo = AppUser(
      id: 'demo-user',
      email: demoEmail,
      name: '김재현',
      phone: '010-0000-0000',
      createdAt: DateTime(2026, 11, 1),
    );
    _usersByEmail[demoEmail] = _Stored(user: demo, password: demoPassword);
  }

  @override
  AuthSession? get current => _session;

  @override
  Future<AuthSession> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    final key = email.trim().toLowerCase();
    if (!key.contains('@')) throw StateError('이메일을 확인해 주세요');
    if (password.length < 4) throw StateError('비밀번호는 4자 이상이어야 합니다');
    if (_usersByEmail.containsKey(key)) throw StateError('이미 가입된 이메일입니다');
    final user = AppUser(
      id: _uuid.v4(),
      email: key,
      name: name.trim(),
      phone: phone,
      createdAt: DateTime.now(),
    );
    _usersByEmail[key] = _Stored(user: user, password: password);
    _session = AuthSession(accessToken: 'mock-${user.id}', user: user);
    return _session!;
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    final stored = _usersByEmail[key];
    if (stored == null || stored.password != password) {
      throw StateError('이메일 또는 비밀번호가 올바르지 않습니다');
    }
    _session = AuthSession(accessToken: 'mock-${stored.user.id}', user: stored.user);
    return _session!;
  }

  @override
  Future<AppUser> me() async {
    final s = _session;
    if (s == null) throw StateError('로그인이 필요합니다');
    return s.user;
  }

  @override
  Future<void> logout() async {
    _session = null;
  }
}

class _Stored {
  _Stored({required this.user, required this.password});
  final AppUser user;
  final String password;
}
