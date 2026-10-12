import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(familyProvider).value;
    final children = ref.watch(childrenProvider);
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final me = ref.watch(sessionProvider).value?.uid;
    final guardians = members.where((m) => m.role == 'parent').toList();
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(family?.name ?? 'Family')),
      body: AsyncView(
        value: children,
        builder: (kids) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          if (family != null)
            Card(
              child: ListTile(
                onTap: () => context.push('/p/plans'),
                leading: Icon(family.isPaid ? Icons.workspace_premium_rounded : Icons.star_outline_rounded, color: t.colorScheme.primary),
                title: Text('${family.planId == 'free' ? 'Free' : family.planId.split('_').first[0].toUpperCase() + family.planId.split('_').first.substring(1)} plan',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(family.isPaid ? 'Thank you for supporting Rakawala' : 'Upgrade for more children, SMS SOS and voice SOS'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          SectionHeader('Children', trailing: TextButton.icon(onPressed: () => _addChild(context, ref), icon: const Icon(Icons.add), label: const Text('Add child'))),
          if (kids.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Icon(Icons.phone_android_rounded, size: 40),
                  const SizedBox(height: 8),
                  const Text('Install Rakawala on your child\'s phone, choose "This is my child\'s phone", then enter the code we give you.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => _addChild(context, ref), child: const Text('Add child')),
                ]),
              ),
            ),
          for (final c in kids)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  onTap: () => context.push('/p/child/${c.id}'),
                  leading: ChildAvatar(label: c.initials, color: c.color, size: 40),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(c.paired ? (c.deviceName ?? 'Connected') : 'Not connected'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
          SectionHeader('Guardians', trailing: TextButton.icon(onPressed: () => _invite(context, ref), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Invite'))),
          for (final g in guardians)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                  title: Text('${g.name}${g.uid == me ? ' (you)' : ''}'),
                  subtitle: Text([if (g.owner) 'Owner', g.phone ?? 'No phone for SMS'].join(' · ')),
                  trailing: family?.ownerUid == me && g.uid != me
                      ? IconButton(
                          icon: const Icon(Icons.person_remove_alt_1_rounded),
                          onPressed: () => runGuarded(context, () => ref.read(apiProvider).removeGuardian(g.uid), success: '${g.name} removed'),
                        )
                      : null,
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _addChild(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context);
    if (name == null || !context.mounted) return;
    final r = await runGuarded(context, () => ref.read(apiProvider).createChildCode(name));
    if (r == null || !context.mounted) return;
    await _showCode(
      context,
      title: 'Connect $name\'s phone',
      steps: const ['Install Rakawala on your child\'s phone', 'Tap "This is my child\'s phone"', 'Enter this code'],
      code: r.code,
      expiresAt: r.expiresAt,
    );
  }

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final r = await runGuarded(context, () => ref.read(apiProvider).createGuardianInvite());
    if (r == null || !context.mounted) return;
    await _showCode(
      context,
      title: 'Invite a guardian',
      steps: const ['They install Rakawala and create an account', 'Choose "Join with code"', 'Enter this code'],
      code: r.code,
      expiresAt: r.expiresAt,
    );
  }

  Future<String?> _askName(BuildContext context) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Child's name"),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Nimal')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim().isEmpty ? null : c.text.trim()), child: const Text('Next')),
        ],
      ),
    );
  }
}

Future<void> _showCode(BuildContext context, {required String title, required List<String> steps, required String code, required DateTime expiresAt}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _CodeSheet(title: title, steps: steps, code: code, expiresAt: expiresAt),
    );

class _CodeSheet extends StatefulWidget {
  const _CodeSheet({required this.title, required this.steps, required this.code, required this.expiresAt});
  final String title;
  final List<String> steps;
  final String code;
  final DateTime expiresAt;
  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final left = widget.expiresAt.difference(DateTime.now());
    final expired = left.isNegative;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.title, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final (i, s) in widget.steps.indexed) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${i + 1}. $s')),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text(
                expired ? 'EXPIRED' : widget.code,
                style: t.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 6, color: t.colorScheme.onPrimaryContainer, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            expired ? 'This code expired. Close and create a new one.' : 'Expires in ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')} · works once · never share it publicly',
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall,
          ),
        ]),
      ),
    );
  }
}
