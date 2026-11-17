import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'address_screens.dart';
import 'cart_screen.dart';
import 'main_shell.dart';
import 'order_screens.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String? _addressId;
  int _dayIndex = 0;
  String? _slot;
  String _payment = 'COD';
  final _note = TextEditingController();
  bool _placing = false;

  List<DateTime> get _days => List.generate(3, (i) => DateTime.now().add(Duration(days: i)));

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final s = context.watch<CartProvider>().summary;
    final settings = context.watch<StoreProvider>().settings;
    final slots = settings.deliverySlots.isEmpty ? ['7 AM - 10 AM', '10 AM - 1 PM', '4 PM - 7 PM'] : settings.deliverySlots;
    _addressId ??= auth.defaultAddress?.id;
    final address = auth.addresses.where((a) => a.id == _addressId).firstOrNull ?? auth.defaultAddress;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section('Delivery address', Icons.location_on_outlined,
            trailing: TextButton(
              onPressed: () async {
                final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const AddressListScreen(selectMode: true)));
                if (id != null) setState(() => _addressId = id);
              },
              child: Text(address == null ? 'Add' : 'Change'),
            ),
            child: address == null
                ? GestureDetector(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressFormScreen()));
                      setState(() => _addressId = null);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                          children: [Icon(Icons.add_location_alt_outlined, color: AppColors.primary), SizedBox(width: 10), Text('Add a delivery address')]),
                    ),
                  )
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _chip(address.label),
                      const SizedBox(width: 8),
                      Text(address.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    Text(address.full, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
                    Text('📞 ${address.phone}', style: const TextStyle(color: AppColors.textMuted)),
                  ])),
        _section('Delivery slot', Icons.schedule,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: List.generate(_days.length, (i) {
                  final d = _days[i];
                  final sel = _dayIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _dayIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                        ),
                        child: Column(children: [
                          Text(
                              i == 0
                                  ? 'Today'
                                  : i == 1
                                      ? 'Tomorrow'
                                      : DateFormat('EEE').format(d),
                              style: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.text)),
                          Text(DateFormat('d MMM').format(d), style: TextStyle(fontSize: 12, color: sel ? Colors.white70 : AppColors.textMuted)),
                        ]),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((sl) {
                  final sel = _slot == sl;
                  return ChoiceChip(
                    label: Text(sl),
                    selected: sel,
                    onSelected: (_) => setState(() => _slot = sl),
                    selectedColor: AppColors.soft,
                    side: BorderSide(color: sel ? AppColors.primary : AppColors.border),
                    labelStyle: TextStyle(color: sel ? AppColors.primary : AppColors.text, fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
            ])),
        _section('Payment method', Icons.account_balance_wallet_outlined,
            child: Column(children: [
              _payTile('COD', '💵', 'Cash / UPI on Delivery', 'Pay when your order arrives', enabled: settings.codEnabled),
              const SizedBox(height: 8),
              _payTile('ONLINE', '💳', 'Pay Online', 'UPI, Cards, Netbanking — coming soon', enabled: false),
            ])),
        _section('Delivery instructions', Icons.edit_note,
            child: TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(hintText: 'e.g. Ring the bell, leave at the door…'))),
        _section('Order summary', Icons.receipt_long_outlined, child: BillDetails(s: s)),
        const SizedBox(height: 90),
      ]),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration:
            BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, -4))]),
        child: ElevatedButton(
          onPressed: _placing ? null : () => _place(address),
          child: _placing
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text('Place Order  •  ${rupee(s.grandTotal)}'),
        ),
      ),
    );
  }

  Future<void> _place(Address? address) async {
    if (address == null) return showSnack(context, 'Please add a delivery address', error: true);
    if (_slot == null) return showSnack(context, 'Please choose a delivery slot', error: true);
    setState(() => _placing = true);
    try {
      final order = await context.read<StoreProvider>().placeOrder(
            addressId: address.id,
            paymentMethod: _payment,
            date: DateFormat('yyyy-MM-dd').format(_days[_dayIndex]),
            slot: _slot!,
            note: _note.text.trim(),
          );
      if (!mounted) return;
      context.read<CartProvider>().reset();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => OrderSuccessScreen(order: order)),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
      if (mounted) context.read<CartProvider>().load();
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
      );

  Widget _payTile(String value, String emoji, String title, String sub, {bool enabled = true}) {
    final sel = _payment == value;
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: GestureDetector(
        onTap: enabled ? () => setState(() => _payment = value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel ? AppColors.soft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.6 : 1),
          ),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ]),
            ),
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AppColors.primary : AppColors.textMuted),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, {required Widget child, Widget? trailing}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

/// Animated "order placed" celebration.
class OrderSuccessScreen extends StatefulWidget {
  final Order order;
  const OrderSuccessScreen({super.key, required this.order});
  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..forward();
  final _rnd = Random();
  late final _bits =
      List.generate(26, (i) => (['🥕', '🍅', '🍎', '🥦', '🍌', '🎉', '✨', '🥭'][i % 8], _rnd.nextDouble() * 2 * pi, 120 + _rnd.nextDouble() * 160));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final pop = CurvedAnimation(parent: _c, curve: const Interval(0, .4, curve: Curves.elasticOut)).value;
                  final burst = CurvedAnimation(parent: _c, curve: const Interval(.15, 1, curve: Curves.easeOutCubic)).value;
                  final text = CurvedAnimation(parent: _c, curve: const Interval(.35, .7, curve: Curves.easeOut)).value;
                  return Stack(alignment: Alignment.center, children: [
                    ..._bits.map((b) => Transform.translate(
                          offset: Offset(cos(b.$2) * b.$3 * burst, sin(b.$2) * b.$3 * burst - 60),
                          child: Opacity(opacity: (1 - burst).clamp(0, 1), child: Text(b.$1, style: const TextStyle(fontSize: 26))),
                        )),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Transform.scale(
                        scale: pop,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            gradient: AppColors.greenGradient,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(.35), blurRadius: 30, spreadRadius: 4)],
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 80),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: text,
                        child: Transform.translate(
                          offset: Offset(0, (1 - text) * 20),
                          child: Column(children: [
                            const Text('Order Placed!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text('Order #${o.orderNo}', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 14),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Your fresh basket of ${o.itemCount} items will be delivered ${o.slot != null ? 'between ${o.slot}' : 'soon'}. Total ${rupee(o.grandTotal)} (${o.paymentMethod == 'COD' ? 'Cash on Delivery' : 'Online'}).',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted, height: 1.5),
                              ),
                            ),
                            if (o.savings > 0) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(20)),
                                child: Text('🎉 You saved ${rupee(o.savings)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    ]),
                  ]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
                  child: const Text('Track Order'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    MainShell.switchTab(context, 0);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: const Text('Continue Shopping'),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
