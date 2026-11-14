import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/app_notification.dart';
import '../models/candidate.dart';
import '../models/browse_notice.dart';
import '../models/lost_dog.dart';
import 'api_auth_repository.dart';
import 'repository.dart';

/// API_SPEC.md 에 맞춘 HTTP 클라이언트 (백엔드 연동)
class ApiRepository implements PetSignalRepository {
  ApiRepository({
    required this.baseUrl,
    this.auth,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final ApiAuthRepository? auth;
  final http.Client _client;

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: q);

  Map<String, String> _headers({bool json = false}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    final t = auth?.token;
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  @override
  Future<LostDog> registerLostDog({
    String? photoUrl,
    Uint8List? photoBytes,
    required String breed,
    required String color,
    required String features,
    String? age,
    required DateTime lostDate,
    required double lostLat,
    required double lostLng,
    required String lostAddress,
  }) async {
    final body = {
      'photo_url': photoUrl,
      if (photoBytes != null) 'photo_data': base64Encode(photoBytes),
      'breed': breed,
      'color': color,
      'features': features,
      'age': age,
      'lost_date':
          '${lostDate.year.toString().padLeft(4, '0')}-${lostDate.month.toString().padLeft(2, '0')}-${lostDate.day.toString().padLeft(2, '0')}',
      'lost_lat': lostLat,
      'lost_lng': lostLng,
      'lost_address': lostAddress,
    };
    final res = await _client.post(
      _u('/api/v1/lost-dogs'),
      headers: _headers(json: true),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw StateError('register failed: ${res.statusCode} ${res.body}');
    }
    return LostDog.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  @override
  Future<LostDog> getLostDog(String id) async {
    final res = await _client.get(_u('/api/v1/lost-dogs/$id'), headers: _headers());
    if (res.statusCode != 200) throw StateError('get lost dog failed');
    return LostDog.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  @override
  Future<List<Candidate>> getCandidates(String lostDogId, {int limit = 20}) async {
    final res = await _client.get(
      _u('/api/v1/lost-dogs/$lostDogId/candidates', {'limit': '$limit'}),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw StateError('candidates failed');
    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>? ?? [];
    return items.map((e) => Candidate.fromJson(e as Map<String, dynamic>, baseUrl: baseUrl)).toList();
  }

  @override
  Future<Candidate> getCandidateDetail(String lostDogId, String noticeId) async {
    final res = await _client.get(
      _u('/api/v1/lost-dogs/$lostDogId/candidates/$noticeId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw StateError('candidate detail failed');
    return Candidate.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>, baseUrl: baseUrl);
  }

  @override
  Future<List<AppNotification>> getNotifications(String lostDogId) async {
    final res = await _client.get(
      _u('/api/v1/lost-dogs/$lostDogId/notifications'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw StateError('notifications failed');
    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final items = map['items'] as List<dynamic>? ?? [];
    return items.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final res = await _client.post(
      _u('/api/v1/notifications/$notificationId/read'),
      headers: _headers(),
    );
    if (res.statusCode != 200) throw StateError('mark read failed');
  }

  @override
  Future<NearbyPage> listNearbyNotices({
    double? lat,
    double? lng,
    String? region,
    String? kind,
    String? color,
    int? days,
    double? radius,
    int page = 1,
    int pageSize = 20,
  }) async {
    final q = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (region != null && region.isNotEmpty) 'region': region,
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      if (color != null && color.isNotEmpty) 'color': color,
      if (days != null) 'days': '$days',
      if (radius != null) 'radius': '$radius',
    };
    final res = await _client.get(_u('/api/v1/notices/nearby', q), headers: _headers());
    if (res.statusCode != 200) {
      throw StateError('nearby failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final items = ((j['items'] as List?) ?? [])
        .map((e) => BrowseNotice.fromJson(e as Map<String, dynamic>, baseUrl: baseUrl))
        .toList();
    return NearbyPage(
      originLat: (j['origin_lat'] as num).toDouble(),
      originLng: (j['origin_lng'] as num).toDouble(),
      originLabel: (j['origin_label'] as String?) ?? '',
      total: (j['total'] as num?)?.toInt() ?? items.length,
      page: (j['page'] as num?)?.toInt() ?? page,
      pageSize: (j['page_size'] as num?)?.toInt() ?? pageSize,
      items: items,
    );
  }

  @override
  Future<BrowseNotice> getNotice(String noticeId) async {
    final res = await _client.get(_u('/api/v1/notices/$noticeId'), headers: _headers());
    if (res.statusCode != 200) throw StateError('get notice failed: ${res.statusCode}');
    return BrowseNotice.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>, baseUrl: baseUrl);
  }
}
