import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/job_model.dart';

class SampleJobDetailsScreen extends StatefulWidget {
  final JobModel job;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final VoidCallback onPreviewApply;

  const SampleJobDetailsScreen({
    super.key,
    required this.job,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onPreviewApply,
  });

  @override
  State<SampleJobDetailsScreen> createState() => _SampleJobDetailsScreenState();
}

class _SampleJobDetailsScreenState extends State<SampleJobDetailsScreen> {
  late bool _isSaved = widget.isSaved;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job preview'),
        actions: [
          IconButton(
            tooltip: _isSaved ? 'Remove preview bookmark' : 'Save preview job',
            onPressed: () {
              setState(() => _isSaved = !_isSaved);
              widget.onToggleSaved();
            },
            icon: Icon(
              _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            color: AppTheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'SAMPLE JOB · PREVIEW ONLY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  job.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1.17,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  job.companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _headerFact(Icons.location_on_outlined, job.locationCity),
                    _headerFact(Icons.work_outline_rounded, job.workMode),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'This fictional listing demonstrates the candidate experience. No employer will receive an application.',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle('Pay'),
                const SizedBox(height: 7),
                Text(
                  job.salaryText,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                _sectionTitle('About this role'),
                const SizedBox(height: 8),
                Text(
                  job.description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (job.requirements.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _sectionTitle('Qualifications'),
                  const SizedBox(height: 8),
                  ...job.requirements.map(_bullet),
                ],
                if (job.responsibilities.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _sectionTitle('Responsibilities'),
                  const SizedBox(height: 8),
                  ...job.responsibilities.map(_bullet),
                ],
                const SizedBox(height: 22),
                _sectionTitle('Employer contact'),
                const SizedBox(height: 7),
                const Text(
                  'Contact details become available on real jobs when provided by the employer.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.onPreviewApply,
              child: const Text('Preview apply'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerFact(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white, size: 17),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
    ],
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: AppTheme.textPrimary,
    ),
  );

  Widget _bullet(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  ', style: TextStyle(color: AppTheme.primary)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
