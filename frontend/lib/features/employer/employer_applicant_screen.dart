import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/employer_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/employer_profile.dart';
import 'employer_plan_screen.dart';

class EmployerApplicantScreen extends StatefulWidget {
  final Map<String, dynamic> application;
  final EmployerProfile profile;

  const EmployerApplicantScreen({super.key, required this.application, required this.profile});

  @override
  State<EmployerApplicantScreen> createState() => _EmployerApplicantScreenState();
}

class _EmployerApplicantScreenState extends State<EmployerApplicantScreen> {
  final _api = EmployerApiService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _resumeBusy = false;
  late String _status = '${widget.application['status'] ?? 'Applied'}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _data = null; });
    try {
      final data = await _api.viewApplicant('${widget.application['id']}');
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _busy = true);
    try {
      await _api.updateApplication('${widget.application['id']}', status);
      if (mounted) setState(() => _status = status);
    } catch (error) { _message(error); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _message(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error.toString().replaceFirst('Bad state: ', '')),
    ));
  }

  Future<({Uint8List bytes, String name})> _resumeBytes() async {
    final data = await _api.viewApplicant('${widget.application['id']}');
    if (mounted) setState(() => _data = data);
    final url = data['resumeUrl']?.toString() ?? '';
    if (url.isEmpty) throw StateError('This application has no resume.');
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw StateError('Could not load the resume. Try again.');
    }
    if (response.bodyBytes.length > 5 * 1024 * 1024) {
      throw StateError('This resume exceeds the 5 MB download limit.');
    }
    final originalName = data['resumeFileName']?.toString() ?? 'resume.pdf';
    final safeName = originalName.replaceAll(RegExp(r'[/\\]'), '_');
    return (bytes: response.bodyBytes, name: safeName);
  }

  Future<void> _previewResume() async {
    setState(() => _resumeBusy = true);
    try {
      final resume = await _resumeBytes();
      if (resume.bytes.length < 4 || resume.bytes[0] != 0x25 ||
          resume.bytes[1] != 0x50 || resume.bytes[2] != 0x44 || resume.bytes[3] != 0x46) {
        throw StateError('This file cannot be previewed as a PDF. You can download it instead.');
      }
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => _ResumePreview(bytes: resume.bytes, fileName: resume.name),
      ));
    } catch (error) { _message(error); }
    finally { if (mounted) setState(() => _resumeBusy = false); }
  }

  Future<void> _downloadResume() async {
    setState(() => _resumeBusy = true);
    try {
      final resume = await _resumeBytes();
      final extension = resume.name.split('.').last.toLowerCase();
      final mime = extension == 'pdf' ? 'application/pdf' : extension == 'doc'
          ? 'application/msword'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      final saved = await FilePicker.saveFile(fileName: resume.name,
        bytes: resume.bytes, mimeType: mime);
      if (saved != null) _message('Resume saved.');
    } catch (error) { _message(error); }
    finally { if (mounted) setState(() => _resumeBusy = false); }
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  String _appliedDate(Object? value) {
    final parsed = DateTime.tryParse(_text(value));
    return parsed == null ? '' : MaterialLocalizations.of(context).formatMediumDate(parsed.toLocal());
  }

  Widget _field(String label, Object? raw) {
    final value = _text(raw);
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary, height: 1.4)),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8E5))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary)),
      const SizedBox(height: 15),
      ...children,
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final application = Map<String, dynamic>.from(_data?['application'] as Map? ?? {});
    final profile = Map<String, dynamic>.from(_data?['candidateProfile'] as Map? ?? {});
    final photo = _text(_data?['profilePhotoUrl']);
    final name = _text(_data?['name']).isNotEmpty ? _text(_data?['name'])
        : _text(widget.application['candidateName']);
    final skills = (application['skills'] as List?)?.map((item) => item.toString()).toList() ?? [];
    final roles = (profile['preferredJobTitles'] as List?)?.map((item) => item.toString()).toList() ?? [];
    final resumeName = _text(_data?['resumeFileName']);
    final hasResume = _text(_data?['resumeUrl']).isNotEmpty;
    final isPdf = resumeName.toLowerCase().endsWith('.pdf');

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(title: const Text('Applicant profile'), backgroundColor: Colors.white,
        surfaceTintColor: Colors.white, actions: [
          IconButton(onPressed: _loading ? null : _load,
            tooltip: 'Refresh applicant', icon: const Icon(Icons.refresh)),
        ]),
      body: _loading && _data == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _data == null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
                  mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_off_outlined, size: 38, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    if (_error!.contains('plan') || _error!.contains('unlocks'))
                      OutlinedButton(onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(
                          builder: (_) => EmployerPlanScreen(profile: widget.profile)));
                        if (mounted) _load();
                      }, child: const Text('View hiring plans')),
                    TextButton(onPressed: _load, child: const Text('Try again')),
                  ])))
              : SafeArea(
                  top: false,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 36 + MediaQuery.paddingOf(context).bottom),
                    children: [
                  Container(padding: const EdgeInsets.all(18),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8E5))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(radius: 27, backgroundColor: const Color(0xFFE9F7EF),
                          backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                          child: photo.isEmpty ? Text(name.isEmpty ? '?' : name[0].toUpperCase()) : null),
                        const SizedBox(width: 13),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name.isEmpty ? 'Applicant' : name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('Applied for ${_text(application['jobTitle'])}',
                            style: const TextStyle(color: AppTheme.textSecondary)),
                        ])),
                      ]),
                      const SizedBox(height: 16),
                      Wrap(spacing: 10, runSpacing: 8, children: [
                        Chip(label: Text(_status), visualDensity: VisualDensity.compact),
                        if (_appliedDate(application['appliedAt']).isNotEmpty)
                          Text('Applied ${_appliedDate(application['appliedAt'])}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ]),
                    ])),
                  _section('Submitted with this application', [
                    _field('Name', application['name']),
                    _field('Email address', application['email']),
                    _field('Phone / WhatsApp number', application['phone']),
                    _field('Current district / city', application['district']),
                    _field('Highest education / degree', application['qualification']),
                    _field('Total work experience', application['experienceLevel']),
                    _field('Notice period', application['noticePeriod']),
                    if (skills.isNotEmpty) _field('Skills', skills.join(', ')),
                    _field('Note to recruiter', application['coverNote']),
                  ]),
                  _section('Current job seeker profile', [
                    _field('Education level', profile['educationLevel']),
                    _field('Qualification', profile['qualification']),
                    _field('College or school', profile['collegeOrSchool']),
                    _field('Graduation year', profile['graduationYear']),
                    if (roles.isNotEmpty) _field('Preferred roles', roles.join(', ')),
                    if (profile['hasExperience'] is bool)
                      _field('Experience', profile['hasExperience'] == true ? 'Experienced' : 'Fresher'),
                    _field('Years of experience', profile['experienceYears']),
                    _field('Months of experience', profile['experienceMonths']),
                    _field('Last company', profile['lastCompany']),
                    _field('Last role', profile['lastJobTitle']),
                  ]),
                  _section('Contact applicant', [
                    if (_text(application['email']).isEmpty)
                      _field('Account email (not captured in this application)', _data?['email']),
                    if (_text(application['phone']).isEmpty)
                      _field('Account phone (not captured in this application)', _data?['phone']),
                    if (_text(_data?['phone']).isNotEmpty)
                      TextButton.icon(onPressed: () => launchUrl(Uri(scheme: 'tel', path: _text(_data?['phone']))),
                        icon: const Icon(Icons.call_outlined), label: const Text('Call applicant')),
                    if (_text(_data?['email']).isNotEmpty)
                      TextButton.icon(onPressed: () => launchUrl(Uri(scheme: 'mailto', path: _text(_data?['email']))),
                        icon: const Icon(Icons.mail_outline), label: const Text('Email applicant')),
                  ]),
                  _section('Resume', [
                    Text(hasResume ? resumeName : 'No resume attached to this application. The candidate can add one from Applied jobs.',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    if (hasResume) Padding(padding: const EdgeInsets.only(top: 12, bottom: 12),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        if (isPdf) OutlinedButton.icon(onPressed: _resumeBusy ? null : _previewResume,
                          icon: const Icon(Icons.visibility_outlined), label: const Text('Preview PDF')),
                        FilledButton.icon(onPressed: _resumeBusy ? null : _downloadResume,
                          icon: const Icon(Icons.download_outlined), label: const Text('Download')),
                      ])),
                  ]),
                  _section('Move application', [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final status in ['Shortlisted', 'Interview', 'Hired', 'Rejected'])
                        OutlinedButton(onPressed: _busy || _status == status ? null
                          : () => _changeStatus(status), child: Text(status)),
                    ]),
                    const SizedBox(height: 8),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _ResumePreview extends StatelessWidget {
  final Uint8List bytes;
  final String fileName;
  const _ResumePreview({required this.bytes, required this.fileName});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
    body: PdfViewer.data(bytes, sourceName: fileName),
  );
}
