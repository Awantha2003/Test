import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../widgets/common.dart';

/// After sign-up: create a new family, or join one with a co-guardian invite code.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  final _family = TextEditingController();
  final _phone = TextEditingController();
  final _invite = TextEditingController();
  bool _joining = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _family, _phone, _invite]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final api = ref.read(apiProvider);
    final phone = _phone.text.replaceAll(' ', '');
    final ok = await runGuarded(context, () async {
      if (_joining) {
        await api.redeemGuardianInvite(code: _invite.text, displayName: _name.text.trim(), phone: phone);
      } else {
        await api.createFamily(familyName: _family.text.trim(), displayName: _name.text.trim(), phone: phone);
      }
      // Pick up the new custom claims; the router then moves to the map.
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      return true;
    });
    if (mounted && ok != true) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: [TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Sign out'))]),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
            Text('Set up your family', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('New family'), icon: Icon(Icons.add_home_rounded)),
                ButtonSegment(value: true, label: Text('Join with code'), icon: Icon(Icons.group_add_rounded)),
              ],
              selected: {_joining},
              onSelectionChanged: (s) => setState(() => _joining = s.first),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name', hintText: 'e.g. Amma, Thaththa, Nimali'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 14),
            if (!_joining)
              TextFormField(
                controller: _family,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Family name', hintText: 'e.g. Perera family'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a family name' : null,
              )
            else
              TextFormField(
                controller: _invite,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Invite code', hintText: 'XXXX-XXXX'),
                validator: (v) => (v ?? '').replaceAll(RegExp(r'[\s-]'), '').length == 8 ? null : 'Enter the 8-character code',
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile number (for SOS SMS)',
                hintText: '+94 77 123 4567',
                helperText: 'Used only to text you in an emergency.',
              ),
              validator: (v) {
                final p = (v ?? '').replaceAll(' ', '');
                return p.isEmpty || RegExp(r'^\+?[0-9]{9,15}$').hasMatch(p) ? null : 'Enter a valid number';
              },
            ),
            const SizedBox(height: 28),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Please wait…' : (_joining ? 'Join family' : 'Create family'))),
          ]),
        ),
      ),
    );
  }
}
