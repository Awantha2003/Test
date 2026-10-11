import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../data/providers.dart';

/// Child phone: enter the 8-character code shown on the parent's phone.
class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});
  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _code = TextEditingController();
  final _device = TextEditingController(text: defaultTargetPlatform == TargetPlatform.iOS ? 'iPhone' : 'Android phone');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _device.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final code = _code.text.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    if (code.length != 8) {
      setState(() => _error = 'The code has 8 letters and numbers.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(apiProvider).redeemPairingCode(
            code: code,
            deviceName: _device.text.trim().isEmpty ? 'Phone' : _device.text.trim(),
            platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          );
      await FirebaseAuth.instance.signInWithCustomToken(r['token'] as String);
      // Router redirects to /child once the session has the child claim.
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on FirebaseAuthException {
      setState(() => _error = 'Could not connect. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to your family')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text('Ask your parent to open Rakawala, tap Family → Add child, and show you the code.', style: t.textTheme.bodyLarge),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 9,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')), _UpperCaseFormatter()],
            style: t.textTheme.headlineMedium?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w800),
            decoration: InputDecoration(hintText: 'XXXX-XXXX', counterText: '', errorText: _error),
            onSubmitted: (_) => _pair(),
          ),
          const SizedBox(height: 12),
          TextField(controller: _device, decoration: const InputDecoration(labelText: 'Name this phone')),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded, color: t.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('What this does', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'This phone will share its location with your family, even when the app is closed, '
                  'so they know you are safe. You will always see a notification while sharing is on. '
                  'You can send an SOS anytime.',
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _pair, child: Text(_busy ? 'Connecting…' : 'Connect')),
        ]),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => newValue.copyWith(text: newValue.text.toUpperCase());
}
