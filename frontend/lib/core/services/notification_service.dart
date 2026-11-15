import 'supabase_service.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime? createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromMap(Map<String, dynamic> data) {
    final title = data['title'];
    final body = data['body'] ?? data['message'];
    final type = data['type'];
    final rawCreated = data['created_at'] ?? data['createdAt'];
    DateTime? created;
    if (rawCreated is DateTime) {
      created = rawCreated;
    } else if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated);
    }
    return AppNotification(
      id: data['id']?.toString() ?? '',
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'Update',
      body: body is String ? body.trim() : '',
      type: type is String ? type : 'general',
      createdAt: created,
      isRead: data['is_read'] == true || data['readAt'] != null,
    );
  }
}

class NotificationService {
  Stream<List<AppNotification>> watchLatest(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    try {
      return SupabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .map((rows) => rows.map(AppNotification.fromMap).toList());
    } catch (_) {
      return Stream.value([]);
    }
  }

  Future<void> markRead(String uid, String notificationId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {}
  }

  Future<void> markAllRead(
    String uid,
    List<AppNotification> notifications,
  ) async {
    final unreadIds = notifications
        .where((item) => !item.isRead)
        .map((i) => i.id)
        .toList();
    if (unreadIds.isEmpty) return;
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .inFilter('id', unreadIds);
    } catch (_) {}
  }
}
