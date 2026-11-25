import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';

Color statusColor(String s) => switch (s) {
      'payment_pending' => const Color(0xFF546E7A),
      'placed' => const Color(0xFF1565C0),
      'confirmed' => const Color(0xFF5E35B1),
      'packed' => const Color(0xFFF57F17),
      'out_for_delivery' => const Color(0xFFE65100),
      'delivered' => AppColors.primary,
      'cancelled' => AppColors.danger,
      _ => AppColors.textMuted,
    };

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Order>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await context.read<StoreProvider>().orders();
      if (mounted) setState(() => _orders = o);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: _error != null
          ? ErrorRetry(
              message: _error!,
              onRetry: () {
                setState(() => _error = null);
                _load();
              })
          : _orders == null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 12), child: ShimmerBox(height: 120))))
              : _orders!.isEmpty
                  ? EmptyState(
                      emoji: '🧾',
                      title: 'No orders yet',
                      message: 'Your orders will appear here once you place one.',
                      actionLabel: 'Shop now',
                      onAction: () => Navigator.pop(context))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final o = _orders![i];
                          final c = statusColor(o.status);
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id)));
                              _load();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration:
                                  BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('#${o.orderNo}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text(DateFormat('d MMM yyyy, h:mm a').format(o.createdAt),
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                    ]),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: c.withOpacity(.1), borderRadius: BorderRadius.circular(20)),
                                    child: Text(orderStatusLabels[o.status] ?? o.status, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
                                  ),
                                ]),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 44,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: o.items
                                        .take(6)
                                        .map((it) => Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: ProductImage(url: it.image, emoji: it.emoji, size: 44, radius: 10)))
                                        .toList(),
                                  ),
                                ),
                                const Divider(height: 22),
                                Row(children: [
                                  Text('${o.itemCount} items', style: const TextStyle(color: AppColors.textMuted)),
                                  const Spacer(),
                                  Text(rupee(o.grandTotal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _o;
  String? _error;

  static const _flow = ['placed', 'confirmed', 'packed', 'out_for_delivery', 'delivered'];
  static const _icons = [Icons.receipt_long, Icons.thumb_up_alt_outlined, Icons.inventory_2_outlined, Icons.delivery_dining, Icons.home_outlined];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await context.read<StoreProvider>().order(widget.orderId);
      if (mounted) setState(() => _o = o);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel order?'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'Reason (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final o = await context.read<StoreProvider>().cancelOrder(_o!.id, reasonCtrl.text.trim().isEmpty ? 'Cancelled by customer' : reasonCtrl.text.trim());
      setState(() => _o = o);
      if (mounted) showSnack(context, 'Order cancelled');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _o;
    return Scaffold(
      appBar: AppBar(title: Text(o == null ? 'Order' : '#${o.orderNo}')),
      body: o == null
          ? (_error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _box(o.status == 'cancelled'
                    ? _cancelled(o)
                    : o.status == 'payment_pending'
                        ? _awaitingPayment(o)
                        : _tracker(o)),
                const SizedBox(height: 12),
                _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o.itemCount} items in this order', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...o.items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          ProductImage(url: it.image, emoji: it.emoji, size: 48, radius: 10),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(it.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${it.variantLabel}  ×  ${it.qty}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ]),
                          ),
                          Text(rupee(it.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      )),
                ])),
                const SizedBox(height: 12),
                _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Bill summary', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _row('Items total', rupee(o.itemsTotal)),
                  if (o.couponDiscount > 0) _row('Coupon (${o.couponCode})', '-${rupee(o.couponDiscount)}', c: AppColors.primary),
                  _row('Delivery fee', o.deliveryFee == 0 ? 'FREE' : rupee(o.deliveryFee)),
                  if (o.handlingFee > 0) _row('Handling charge', rupee(o.handlingFee)),
                  const Divider(),
                  _row('Total', rupee(o.grandTotal), bold: true),
                  _row('Payment', '${o.paymentMethod == 'COD' ? 'Cash on Delivery' : 'Online (Razorpay)'} • ${_payLabel(o.paymentStatus)}'),
                  if (o.paymentId != null) _row('Payment ID', o.paymentId!),
                  if (o.refundId != null) _row('Refund ID', o.refundId!),
                ])),
                const SizedBox(height: 12),
                if (o.address != null)
                  _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Delivery details', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (o.address!.hasLocation) ...[
                      MapPreview(lat: o.address!.lat!, lng: o.address!.lng!, height: 130),
                      const SizedBox(height: 10),
                    ],
                    Text('${o.address!.name} • ${o.address!.phone}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(o.address!.full, style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
                    if (o.slot != null) ...[
                      const SizedBox(height: 6),
                      Text('🕒 ${o.slotDate ?? ''}  ${o.slot}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ])),
                const SizedBox(height: 16),
                if (o.canCancel)
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                      onPressed: _cancel,
                      child: const Text('Cancel Order')),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }

  Widget _box(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: child,
      );

  Widget _row(String l, String r, {Color? c, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(r, style: TextStyle(color: c, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ]),
      );

  String _payLabel(String s) => switch (s) {
        'paid' => 'Paid',
        'pending' => 'Pending',
        'failed' => 'Failed',
        'refunded' => 'Refunded',
        'refund_pending' => 'Refund in progress',
        _ => s,
      };

  Widget _awaitingPayment(Order o) => const Row(children: [
        Text('⏳', style: TextStyle(fontSize: 30)),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Waiting for payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(
                'If money was deducted, this order will be confirmed automatically in a few minutes. '
                'Unpaid orders are cancelled after 30 minutes.',
                style: TextStyle(color: AppColors.textMuted)),
          ]),
        ),
      ]);

  Widget _cancelled(Order o) => Row(children: [
        const Text('❌', style: TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Order cancelled', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger, fontSize: 16)),
            if (o.cancelReason != null) Text(o.cancelReason!, style: const TextStyle(color: AppColors.textMuted)),
            if (o.paymentStatus == 'refunded')
              const Text('💸 Refund started — it reaches your account in 5–7 working days.', style: TextStyle(color: AppColors.primary, fontSize: 12.5)),
            if (o.paymentStatus == 'refund_pending')
              const Text('💸 Your refund is being processed.', style: TextStyle(color: AppColors.primary, fontSize: 12.5)),
          ]),
        ),
      ]);

  Widget _tracker(Order o) {
    final current = _flow.indexOf(o.status);
    DateTime? at(String s) => o.history.where((h) => h.status == s).map((h) => h.at).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(o.status == 'delivered' ? 'Delivered 🎉' : 'Arriving ${o.slotDate != null ? 'on ${o.slotDate}' : 'soon'}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      if (o.slot != null && o.status != 'delivered') Text(o.slot!, style: const TextStyle(color: AppColors.textMuted)),
      const SizedBox(height: 16),
      ...List.generate(_flow.length, (i) {
        final done = i <= current;
        final last = i == _flow.length - 1;
        final t = at(_flow[i]);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: done ? 1 : 0),
          duration: Duration(milliseconds: 400 + i * 200),
          builder: (_, v, __) => IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: Color.lerp(AppColors.bg, AppColors.primary, v), shape: BoxShape.circle),
                  child: Icon(_icons[i], size: 18, color: Color.lerp(AppColors.textMuted, Colors.white, v)),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: i < current ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 6, bottom: last ? 0 : 18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(orderStatusLabels[_flow[i]]!,
                        style: TextStyle(fontWeight: done ? FontWeight.w700 : FontWeight.w500, color: done ? AppColors.text : AppColors.textMuted)),
                    if (t != null) Text(DateFormat('d MMM, h:mm a').format(t), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ]),
                ),
              ),
            ]),
          ),
        );
      }),
    ]);
  }
}
