import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';

import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';

final _lkr = NumberFormat.currency(locale: 'en_LK', symbol: 'LKR ', decimalDigits: 0);

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});
  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String? _busyPlan;

  Future<void> _buy(Plan plan) async {
    setState(() => _busyPlan = plan.id);
    final checkout = await runGuarded(context, () => ref.read(apiProvider).createCheckout(plan.id));
    if (checkout == null || !mounted) {
      setState(() => _busyPlan = null);
      return;
    }
    final p = Map<String, dynamic>.from(checkout['params'] as Map);
    final payment = <String, dynamic>{
      'sandbox': checkout['sandbox'] == true,
      ...p,
      // The SDK expects a number; the server keeps the canonical 2-dp string.
      'amount': double.parse(p['amount'] as String),
    }..removeWhere((k, _) => k == 'return_url' || k == 'cancel_url' || k == 'hash');

    PayHere.startPayment(
      payment,
      (paymentId) {
        if (!mounted) return;
        setState(() => _busyPlan = null);
        // The plan switches when PayHere's server notification reaches us (usually seconds).
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment received. Your plan will update in a moment.')));
      },
      (error) {
        if (!mounted) return;
        setState(() => _busyPlan = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $error')));
      },
      () {
        if (mounted) setState(() => _busyPlan = null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider);
    final family = ref.watch(familyProvider).value;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: AsyncView(
        value: plans,
        builder: (list) => ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          if (family != null && family.isPaid)
            Card(
              color: t.colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_rounded),
                title: Text('Current plan: ${list.where((p) => p.id == family.planId).firstOrNull?.name ?? family.planId}'),
                subtitle: Text(family.planStatus == 'cancelled'
                    ? 'Cancelled: active until ${family.planRenewsAt == null ? '-' : DateFormat.yMMMd().format(family.planRenewsAt!)}'
                    : 'Renews ${family.planRenewsAt == null ? '-' : DateFormat.yMMMd().format(family.planRenewsAt!)}'),
              ),
            ),
          const SizedBox(height: 8),
          Text('SOS alerts are free on every plan. Always.', style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final p in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: p.highlight ? t.colorScheme.primary : t.colorScheme.outlineVariant, width: p.highlight ? 2 : 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(p.name, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const Spacer(),
                      if (p.highlight) Chip(label: const Text('Most popular'), backgroundColor: t.colorScheme.primary, labelStyle: TextStyle(color: t.colorScheme.onPrimary), side: BorderSide.none),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      p.priceLkr == 0 ? 'Free' : '${_lkr.format(p.priceLkr)} / ${p.interval}',
                      style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: t.colorScheme.primary),
                    ),
                    const SizedBox(height: 12),
                    for (final f in p.features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(f))]),
                      ),
                    const SizedBox(height: 12),
                    if (family?.planId == p.id)
                      const OutlinedButton(onPressed: null, child: Text('Current plan'))
                    else if (p.priceLkr > 0)
                      FilledButton(onPressed: _busyPlan != null ? null : () => _buy(p), child: Text(_busyPlan == p.id ? 'Opening PayHere…' : 'Choose ${p.name}')),
                  ]),
                ),
              ),
            ),
          Text('Payments are processed securely by PayHere (Visa, Mastercard, Amex, eZ Cash, mCash, Genie). Cancel anytime.',
              style: t.textTheme.bodySmall, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
