import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/job_model.dart';

class ReportJobSheet extends StatefulWidget {
  const ReportJobSheet({super.key, required this.job, required this.onSubmit});

  final JobModel job;
  final Future<void> Function(String reason, String details) onSubmit;

  @override
  State<ReportJobSheet> createState() => _ReportJobSheetState();
}

class _ReportJobSheetState extends State<ReportJobSheet> {
  static const _reasons = <(String, String)>[
    ('fraud', 'Possible fraud'),
    ('misleading', 'Misleading information'),
    ('duplicate', 'Duplicate job'),
    ('inappropriate', 'Inappropriate content'),
    ('other', 'Something else'),
  ];

  final _details = TextEditingController();
  String? _reason;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = _details.text.trim();
    if (_reason == null) {
      setState(() => _error = 'Choose a reason for your report.');
      return;
    }
    if (_reason == 'other' && details.length < 5) {
      setState(() => _error = 'Tell us a little more (at least 5 characters).');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_reason!, details);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height - keyboard) * .86,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Report this job',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close report form',
                        onPressed: _sending
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.border),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.job.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.job.companyName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'What is wrong with this listing?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final (value, label) in _reasons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Material(
                              color: _reason == value
                                  ? AppTheme.primaryLight
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _sending
                                    ? null
                                    : () => setState(() {
                                        _reason = value;
                                        _error = null;
                                      }),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _reason == value
                                          ? AppTheme.primary
                                          : AppTheme.border,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _reason == value
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_off,
                                        size: 20,
                                        color: _reason == value
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _details,
                          maxLines: 3,
                          minLines: 3,
                          maxLength: 500,
                          enabled: !_sending,
                          decoration: InputDecoration(
                            labelText: _reason == 'other'
                                ? 'Tell us more *'
                                : 'Tell us more (optional)',
                            hintText: 'Share details that will help our team review the job.',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                            ),
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppTheme.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const Text(
                          'Only the Career360 admin team can review your report.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _sending ? null : _submit,
                      child: Text(_sending ? 'Sending report…' : 'Send report'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
