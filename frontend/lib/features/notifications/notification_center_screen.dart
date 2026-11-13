import 'package:flutter/material.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  final String? uid;

  const NotificationCenterScreen({super.key, required this.uid});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _service = NotificationService();
  Stream<List<AppNotification>>? _notifications;
  bool _unreadOnly = false;
  bool _markingAllRead = false;
  final Set<String> _markingRead = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = widget.uid;
    if (uid != null) {
      _notifications = _service.watchLatest(uid);
    }
  }

  Future<void> _markRead(AppNotification item) async {
    final uid = widget.uid;
    if (uid == null || item.isRead || _markingRead.contains(item.id)) return;
    setState(() => _markingRead.add(item.id));
    try {
      await _service.markRead(uid, item.id);
    } catch (_) {
      _showMessage('Could not mark this notification as read.');
    } finally {
      if (mounted) setState(() => _markingRead.remove(item.id));
    }
  }

  Future<void> _markAllRead(List<AppNotification> notifications) async {
    final uid = widget.uid;
    if (uid == null || _markingAllRead) return;
    setState(() => _markingAllRead = true);
    try {
      await _service.markAllRead(uid, notifications);
    } catch (_) {
      _showMessage('Could not mark all notifications as read.');
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: widget.uid == null
                ? _buildMessage(
                    icon: Icons.lock_outline_rounded,
                    title: 'Sign in to see notifications',
                    description:
                        'Your updates will appear here after you sign in.',
                  )
                : StreamBuilder<List<AppNotification>>(
                    stream: _notifications,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildMessage(
                          icon: Icons.wifi_off_rounded,
                          title: 'Could not load notifications',
                          description: 'Check your connection and try again.',
                          action: TextButton.icon(
                            onPressed: () => setState(_reload),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildContent(snapshot.data!);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<AppNotification> notifications) {
    final unreadCount = notifications.where((item) => !item.isRead).length;
    final visible = _unreadOnly
        ? notifications.where((item) => !item.isRead).toList()
        : notifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your updates',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unreadCount == 0
                          ? 'You are all caught up'
                          : '$unreadCount unread ${unreadCount == 1 ? 'notification' : 'notifications'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _filterChip(
                'All',
                selected: !_unreadOnly,
                onTap: () {
                  setState(() => _unreadOnly = false);
                },
              ),
              _filterChip(
                'Unread',
                selected: _unreadOnly,
                onTap: () {
                  setState(() => _unreadOnly = true);
                },
              ),
              if (unreadCount > 0)
                TextButton(
                  onPressed: _markingAllRead
                      ? null
                      : () => _markAllRead(notifications),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? _buildMessage(
                  icon: _unreadOnly
                      ? Icons.done_all_rounded
                      : Icons.notifications_off_outlined,
                  title: _unreadOnly
                      ? 'No unread updates'
                      : 'No notifications yet',
                  description: _unreadOnly
                      ? 'You have read all your notifications.'
                      : 'Updates sent to your account will appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _buildNotification(visible[index]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppTheme.primaryLight,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppTheme.primary : AppTheme.border),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildNotification(AppNotification item) {
    final (icon, tint) = switch (item.type) {
      'application' => (Icons.assignment_turned_in_outlined, AppTheme.success),
      'job' => (Icons.work_outline_rounded, AppTheme.primary),
      'interview' => (Icons.event_available_outlined, AppTheme.warning),
      _ => (Icons.notifications_none_rounded, AppTheme.primary),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRead
              ? AppTheme.border
              : AppTheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: tint, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: item.isRead
                              ? FontWeight.w600
                              : FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!item.isRead) ...[
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: AppTheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _timeLabel(item.createdAt),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (!item.isRead)
                      TextButton(
                        onPressed: _markingRead.contains(item.id)
                            ? null
                            : () => _markRead(item),
                        child: const Text('Mark read'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime? timestamp) {
    if (timestamp == null) return 'Recent';
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final date = DateUtils.dateOnly(local);
    final time = TimeOfDay.fromDateTime(local).format(context);
    if (date == today) return 'Today · $time';
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · $time';
    }
    return '${MaterialLocalizations.of(context).formatMediumDate(local)} · $time';
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String description,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
