import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory AppNotification.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final title = data['title'];
    final body = data['body'];
    final type = data['type'];
    final createdAt = data['createdAt'];
    return AppNotification(
      id: document.id,
      title: title is String && title.trim().isNotEmpty
          ? title.trim()
          : 'Update',
      body: body is String ? body.trim() : '',
      type: type is String ? type : 'general',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      isRead: data['readAt'] != null,
    );
  }
}

class NotificationService {
  final FirebaseFirestore _firestore;

  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watchLatest(String uid) => _collection(uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map(AppNotification.fromDocument).toList(),
      );

  Future<void> markRead(String uid, String notificationId) =>
      _collection(uid)
          .doc(notificationId)
          .update({'readAt': FieldValue.serverTimestamp()});

  Future<void> markAllRead(
    String uid,
    List<AppNotification> notifications,
  ) async {
    final unread = notifications.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    final batch = _firestore.batch();
    for (final item in unread) {
      batch.update(_collection(uid).doc(item.id), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
