import '../models/user.dart';

abstract class AuthRepository {
  AuthSession? get current;
  Future<AuthSession> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
  });
  Future<AuthSession> login({required String email, required String password});
  Future<AppUser> me();
  Future<void> logout();
}
