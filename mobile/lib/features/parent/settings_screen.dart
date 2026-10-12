import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../services/app_lock.dart';
import '../../services/push_service.dart';
import '../../widgets/common.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _lock;
  bool _lockSupported = false;

  @override
  void initState() {
    super.initState();
    Future.wait([AppLock.isEnabled(), AppLock.isSupported()]).then((r) {
      if (!mounted) return;
      setState(() {
        _lock = r[0];
        _lockSupported = r[1];
      });
    });
  }

  Future<void> _editPhone(Member me) async {
    final c = TextEditingController(text: me.phone ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mobile for SOS SMS'),
        content: TextField(controller: c, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '+94 77 123 4567')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.replaceAll(' ', '')), child: const Text('Save')),
        ],
      ),
    );
    if (v == null || !mounted) return;
    if (v.isNotEmpty && !RegExp(r'^\+?[0-9]{9,15}$').hasMatch(v)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid number.')));
      return;
    }
    final fid = ref.read(sessionProvider).value!.familyId!;
    await runGuarded(context, () => familyCol(fid, 'members').doc(me.uid).update({'name': me.name, 'phone': v.isEmpty ? null : v}), success: 'Saved');
  }

  Future<void> _signOut() async {
    final uid = ref.read(sessionProvider).value?.uid;
    if (uid != null) await PushService.unregister(uid).catchError((_) {});
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteAccount(bool owner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(owner
            ? 'This deletes your whole family: all children, places, history and alerts. Children\'s phones stop sharing. This cannot be undone.'
            : 'You will leave this family and your account will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await runGuarded(context, () => ref.read(apiProvider).deleteMyAccount().then((_) => true));
    if (done == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    final family = ref.watch(familyProvider).value;
    final me = (ref.watch(membersProvider).value ?? const <Member>[]).where((m) => m.uid == session?.uid).firstOrNull;
    final owner = family?.ownerUid == session?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
        const SectionHeader('Account'),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.person_rounded), title: Text(me?.name ?? ''), subtitle: Text(session?.email ?? '')),
            if (me != null)
              ListTile(
                leading: const Icon(Icons.sms_rounded),
                title: const Text('SOS SMS number'),
                subtitle: Text(me.phone ?? 'Not set: you won\'t get SOS by SMS'),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () => _editPhone(me),
              ),
            ListTile(leading: const Icon(Icons.workspace_premium_rounded), title: const Text('Plan & billing'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => context.push('/p/plans')),
          ]),
        ),
        const SectionHeader('Security'),
        Card(
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('App lock'),
              subtitle: Text(_lockSupported ? 'Require fingerprint, face or PIN to open' : 'Not supported on this device'),
              value: _lock ?? false,
              onChanged: !_lockSupported
                  ? null
                  : (v) async {
                      final ok = await AppLock.setEnabled(v);
                      if (ok && mounted) setState(() => _lock = v);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Change password'),
              onTap: () async {
                final email = session?.email;
                if (email == null) return;
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset link sent to $email')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices_rounded),
              title: const Text('Sign out of this device'),
              onTap: _signOut,
            ),
          ]),
        ),
        const SectionHeader('Help'),
        Card(
          child: Column(children: [
            ListTile(leading: const Icon(Icons.support_agent_rounded), title: const Text('Contact support'), onTap: () => launchUrl(Uri(scheme: 'tel', path: AppConfig.supportPhone))),
            ListTile(leading: const Icon(Icons.privacy_tip_rounded), title: const Text('Privacy policy'), onTap: () => launchUrl(Uri.parse('${AppConfig.webUrl}/privacy'))),
            ListTile(leading: const Icon(Icons.description_rounded), title: const Text('Terms'), onTap: () => launchUrl(Uri.parse('${AppConfig.webUrl}/terms'))),
          ]),
        ),
        const SectionHeader('Danger zone'),
        Card(
          child: ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
            title: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: Text(owner ? 'Deletes your family and all data' : 'Leave the family and delete your account'),
            onTap: () => _deleteAccount(owner),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text('Rakawala · ${FirebaseFirestore.instance.app.options.projectId}', style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}
