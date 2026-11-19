import 'package:flutter/material.dart';

import '../../core/services/supabase_service.dart';
import '../../data/models/job_model.dart';

class InstitutionWorkspaceScreen extends StatefulWidget {
  const InstitutionWorkspaceScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.metadata,
    required this.onSignOut,
  });

  final String userId;
  final String email;
  final Map<String, dynamic> metadata;
  final VoidCallback onSignOut;

  @override
  State<InstitutionWorkspaceScreen> createState() => _InstitutionWorkspaceScreenState();
}

class _InstitutionWorkspaceScreenState extends State<InstitutionWorkspaceScreen> {
  late Stream<Map<String, dynamic>?> _profile;
  final _name = TextEditingController();
  final _type = TextEditingController();
  final _coordinator = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _editing = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _profile = _watch();
    _name.text = widget.metadata['institution_name']?.toString() ?? '';
    _type.text = widget.metadata['institution_type']?.toString() ?? '';
    _coordinator.text = widget.metadata['coordinator_name']?.toString() ??
        widget.metadata['full_name']?.toString() ?? '';
    _phone.text = widget.metadata['institution_phone']?.toString() ?? '';
  }

  Stream<Map<String, dynamic>?> _watch() => SupabaseService.client
      .from('institutions').stream(primaryKey: ['id'])
      .eq('user_id', widget.userId)
      .map((rows) => rows.isEmpty ? null : rows.first);

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _coordinator.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().length < 2 || _type.text.trim().length < 2 ||
        _coordinator.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the institution, type, and coordinator name.'),
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final client = SupabaseService.client;
      if (client.auth.currentUser?.id != widget.userId) {
        throw StateError('Sign in again to save your institution.');
      }
      await client.from('profiles').upsert({
        'id': widget.userId,
        'email': widget.email,
        'role': 'INSTITUTION',
        'updated_at': DateTime.now().toIso8601String(),
      });
      await client.from('institutions').upsert({
        'user_id': widget.userId,
        'name': _name.text.trim(),
        'institution_type': _type.text.trim(),
        'coordinator_name': _coordinator.text.trim(),
        'phone': _phone.text.trim(),
        'email': widget.email,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      if (mounted) setState(() => _editing = false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save institution details: $error'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _form() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Text('Institution details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('These details are saved to your institution account.'),
      const SizedBox(height: 24),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Institution name')),
      const SizedBox(height: 14),
      TextField(controller: _type, decoration: const InputDecoration(labelText: 'Institution type')),
      const SizedBox(height: 14),
      TextField(controller: _coordinator, decoration: const InputDecoration(labelText: 'Placement coordinator')),
      const SizedBox(height: 14),
      TextField(controller: _phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Contact number')),
      const SizedBox(height: 14),
      TextFormField(initialValue: widget.email, readOnly: true,
          decoration: const InputDecoration(labelText: 'Account email')),
      const SizedBox(height: 24),
      FilledButton(onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save details')),
      if (_editing) TextButton(onPressed: () => setState(() => _editing = false),
          child: const Text('Cancel')),
    ],
  );

  Widget _jobs() => StreamBuilder<List<Map<String, dynamic>>>(
    stream: SupabaseService.streamPublishedJobs(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Center(child: Text('Could not load jobs.'));
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final jobs = snapshot.data!.map(JobModel.fromMap).toList();
      if (jobs.isEmpty) return const Center(child: Text('No published jobs yet.'));
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final job = jobs[index];
          return Card(child: ListTile(
            title: Text(job.title),
            subtitle: Text('${job.locationCity} · ${job.category}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showDialog<void>(context: context, builder: (_) => AlertDialog(
              title: Text(job.title),
              content: SingleChildScrollView(child: Text(job.description)),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            )),
          ));
        },
      );
    },
  );

  Widget _details(Map<String, dynamic> profile) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(profile['name']?.toString() ?? '',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(profile['institution_type']?.toString() ?? ''),
      const Divider(height: 32),
      ListTile(title: const Text('Coordinator'), subtitle: Text(profile['coordinator_name']?.toString() ?? '')),
      ListTile(title: const Text('Phone'), subtitle: Text(profile['phone']?.toString() ?? '')),
      ListTile(title: const Text('Email'), subtitle: Text(profile['email']?.toString() ?? '')),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: () {
        _name.text = profile['name']?.toString() ?? '';
        _type.text = profile['institution_type']?.toString() ?? '';
        _coordinator.text = profile['coordinator_name']?.toString() ?? '';
        _phone.text = profile['phone']?.toString() ?? '';
        setState(() => _editing = true);
      }, icon: const Icon(Icons.edit_outlined), label: const Text('Edit institution')),
    ],
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>?>(
    stream: _profile,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
        appBar: AppBar(title: const Text('Institution')),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Could not load institution details.'),
          TextButton(onPressed: () => setState(() => _profile = _watch()), child: const Text('Retry')),
        ])),
        );
      }
      if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final profile = snapshot.data;
      return Scaffold(
        appBar: AppBar(title: const Text('Institution portal'), actions: [
          IconButton(onPressed: widget.onSignOut, tooltip: 'Sign out',
              icon: const Icon(Icons.logout_outlined)),
        ]),
        body: profile == null || _editing ? _form() :
            _tab == 0 ? _jobs() : _details(profile),
        bottomNavigationBar: profile == null ? null : NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
            NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Institution'),
          ],
        ),
      );
    },
  );
}
