/// 실종견 등록 정보
class LostDog {
  final String id;
  final String? photoUrl;
  final String breed;
  final String color;
  final String features;
  final String? age;
  final DateTime lostDate;
  final double lostLat;
  final double lostLng;
  final String lostAddress;
  final DateTime createdAt;

  LostDog({
    required this.id,
    this.photoUrl,
    required this.breed,
    required this.color,
    required this.features,
    this.age,
    required this.lostDate,
    required this.lostLat,
    required this.lostLng,
    required this.lostAddress,
    required this.createdAt,
  });

  factory LostDog.fromJson(Map<String, dynamic> j) => LostDog(
        id: j['id'] as String,
        photoUrl: j['photo_url'] as String?,
        breed: j['breed'] as String,
        color: j['color'] as String,
        features: j['features'] as String? ?? '',
        age: j['age'] as String?,
        lostDate: DateTime.parse(j['lost_date'] as String),
        lostLat: (j['lost_lat'] as num).toDouble(),
        lostLng: (j['lost_lng'] as num).toDouble(),
        lostAddress: j['lost_address'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toCreateJson() => {
        'photo_url': photoUrl,
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
}
