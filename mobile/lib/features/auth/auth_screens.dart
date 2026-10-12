import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Strong-enough password policy for an app that guards children's locations.
String? validatePassword(String? v) {
  final p = v ?? '';
  if (p.length < 10) return 'Use at least 10 characters';
  if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) return 'Use letters and numbers';
  return null;
}

String? validateEmail(String? v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email';

String authMessage(FirebaseAuthException e) => switch (e.code) {
      'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' => 'Email or password is incorrect.',
      'email-already-in-use' => 'An account already exists with this email. Try signing in.',
      'too-many-requests' => 'Too many attempts. Please wait a few minutes.',
      'network-request-failed' => 'No internet connection.',
      'user-disabled' => 'This account has been disabled. Contact support.',
      _ => 'Sign-in failed. Please try again.',
    };

Future<void> signInWithGoogle(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final google = GoogleSignIn.instance;
    await google.initialize();
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
  } on GoogleSignInException catch (e) {
    if (e.code != GoogleSignInExceptionCode.canceled) {
      messenger.showSnackBar(const SnackBar(content: Text('Google sign-in failed.')));
    }
  } on FirebaseAuthException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(authMessage(e))));
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
          Text(title, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 28),
          ...children,
        ]),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (validateEmail(_email.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    // Same message whether or not the account exists (no account enumeration).
    unawaited(FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim()).catchError((_) {}));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('If an account exists, a reset link is on its way.')));
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Welcome back',
        subtitle: 'Sign in to see your family.',
        children: [
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                  ),
                  validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ]),
            ),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _reset, child: const Text('Forgot password?'))),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const _Spinner() : const Text('Sign in')),
          const _OrDivider(),
          OutlinedButton.icon(onPressed: () => signInWithGoogle(context), icon: const Icon(Icons.g_mobiledata_rounded, size: 30), label: const Text('Continue with Google')),
          const SizedBox(height: 16),
          TextButton(onPressed: () => context.pushReplacement('/auth/sign-up'), child: const Text("New here? Create an account")),
        ],
      );
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _consent = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_consent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm you are the parent or legal guardian.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      await cred.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Create your guardian account',
        subtitle: 'Free forever for one child. Upgrade anytime.',
        children: [
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 10 characters, letters and numbers', prefixIcon: Icon(Icons.lock_outline)),
                  validator: validatePassword,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("I'm the parent or legal guardian, and I agree to the Terms and Privacy Policy."),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _submit, child: _busy ? const _Spinner() : const Text('Create account')),
          const _OrDivider(),
          OutlinedButton.icon(
            onPressed: () {
              if (!_consent) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please confirm you are the parent or legal guardian.')));
                return;
              }
              signInWithGoogle(context);
            },
            icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: () => context.pushReplacement('/auth/sign-in'), child: const Text('Already have an account? Sign in')),
        ],
      );
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _poll;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    // Poll so the screen moves on by itself once the link is clicked.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) async {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
        _poll?.cancel();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    return _AuthScaffold(
      title: 'Check your inbox',
      subtitle: 'We sent a verification link to $email. Open it, then come back here.',
      children: [
        const Center(child: Icon(Icons.mark_email_unread_rounded, size: 96)),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: _sent
              ? null
              : () async {
                  await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                  setState(() => _sent = true);
                },
          child: Text(_sent ? 'Link sent' : 'Resend link'),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('Use a different account')),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white));
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')), Expanded(child: Divider())]),
      );
}
