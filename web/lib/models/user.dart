class AppUser {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class AuthSession {
  final String accessToken;
  final AppUser user;

  AuthSession({required this.accessToken, required this.user});
}
