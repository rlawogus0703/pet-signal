class AppNotification {
  final String id;
  final String lostDogId;
  final String noticeId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.lostDogId,
    required this.noticeId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        lostDogId: j['lost_dog_id'] as String,
        noticeId: j['notice_id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        read: j['read'] as bool? ?? false,
      );
}
