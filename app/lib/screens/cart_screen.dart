import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'auth_screens.dart';
import 'checkout_screen.dart';
import 'main_shell.dart';

class CartScreen extends StatefulWidget {
  /// true when shown as a bottom-nav tab (no back button).
  final bool embedded;
  const CartScreen({super.key, this.embedded = false});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<CartProvider>().load());
  }

  void _shop() {
    if (widget.embedded) {
      MainShell.switchTab(context, 0);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cart = context.watch<CartProvider>();
    final s = cart.summary;

    Widget body;
    if (!auth.isLoggedIn) {
      body = EmptyState(
        emoji: '🔐',
        title: 'Login to view your cart',
        message: 'Your basket is saved securely to your account.',
        actionLabel: 'Login',
        onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
      );
    } else if (s.items.isEmpty) {
      body = cart.loading
          ? const Center(child: CircularProgressIndicator())
          : EmptyState(emoji: '🧺', title: 'Your basket is empty', message: 'Fresh fruits & vegetables are waiting for you!', actionLabel: 'Start Shopping', onAction: _shop);
    } else {
      body = RefreshIndicator(
        onRefresh: cart.load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          _FreeDeliveryBar(s: s),
          if (s.warnings.isNotEmpty)
            ...s.warnings.map((w) => Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                  child: Text('⚠️ $w', style: const TextStyle(fontSize: 12.5)),
                )),
          const SizedBox(height: 12),
          _card(Column(children: [
            Row(children: [
              const Icon(Icons.timer_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Delivery in 30–45 mins', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${s.count} items', style: const TextStyle(color: AppColors.textMuted)),
            ]),
            const Divider(height: 24),
            ...s.items.map((i) => _CartLineTile(line: i)),
          ])),
          const SizedBox(height: 12),
          _CouponCard(s: s),
          const SizedBox(height: 12),
          _card(BillDetails(s: s)),
          if (s.savings > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Text('🎉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text('You are saving ${rupee(s.savings)} on this order!', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1565C0)))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          const Text('🛡️  Orders can be cancelled before they are packed. Fresh produce is checked before dispatch.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('My Cart'),
        actions: [
          if (s.items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear cart?'),
                    content: const Text('All items will be removed from your basket.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (ok == true) cart.clear();
              },
              child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
            ),
        ],
      ),
      body: body,
      bottomNavigationBar: s.items.isEmpty || !auth.isLoggedIn
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (widget.embedded ? 0 : MediaQuery.of(context).padding.bottom)),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, -4))]),
              child: Row(children: [
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rupee(s.grandTotal), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const Text('TOTAL', style: TextStyle(fontSize: 11, color: AppColors.textMuted, letterSpacing: 1)),
                  ]),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (s.itemsTotal < s.minOrderAmount) {
                        return showSnack(context, 'Minimum order is ${rupee(s.minOrderAmount)}. Add ${rupee(s.minOrderAmount - s.itemsTotal)} more.', error: true);
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                    },
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Proceed to Checkout'), SizedBox(width: 6), Icon(Icons.arrow_forward, size: 18)]),
                  ),
                ),
              ]),
            ),
    );
  }
}

Widget _card(Widget child) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: child,
    );

class _FreeDeliveryBar extends StatelessWidget {
  final CartSummary s;
  const _FreeDeliveryBar({required this.s});
  @override
  Widget build(BuildContext context) {
    final progress = s.freeDeliveryAbove <= 0 ? 1.0 : (s.itemsTotal / s.freeDeliveryAbove).clamp(0.0, 1.0);
    final done = s.amountForFreeDelivery <= 0;
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(done ? '🎉' : '🚚', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            done ? 'Yay! You get FREE delivery' : 'Add ${rupee(s.amountForFreeDelivery)} more for FREE delivery',
            style: TextStyle(fontWeight: FontWeight.w600, color: done ? AppColors.primary : AppColors.text),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: AppColors.bg, color: AppColors.primaryLight),
        ),
      ),
    ]));
  }
}

class _CartLineTile extends StatelessWidget {
  final CartLine line;
  const _CartLineTile({required this.line});
  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    Future<void> set(int q) async {
      try {
        await cart.setQty(line.productId, line.variantId, q);
      } catch (e) {
        if (context.mounted) showSnack(context, e.toString(), error: true);
      }
    }

    return Dismissible(
      key: ValueKey('${line.productId}${line.variantId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      onDismissed: (_) => set(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          ProductImage(url: line.image, emoji: line.emoji, size: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(line.variantLabel, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              PriceText(price: line.total, mrp: line.mrp * line.qty, size: 14),
            ]),
          ),
          Container(
            height: 34,
            decoration: BoxDecoration(gradient: AppColors.greenGradient, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(line.qty == 1 ? Icons.delete_outline : Icons.remove, color: Colors.white, size: 18),
                onPressed: () => set(line.qty - 1),
              ),
              Text('${line.qty}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                onPressed: () {
                  if (line.qty >= line.maxPerOrder || line.qty >= line.stock) return showSnack(context, 'Maximum quantity reached', error: true);
                  set(line.qty + 1);
                },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CartSummary s;
  const _CouponCard({required this.s});

  Future<void> _open(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final coupons = await context.read<StoreProvider>().coupons().catchError((_) => <Coupon>[]);
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        Future<void> apply(String code) async {
          try {
            await cart.applyCoupon(code);
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) showSnack(context, '🎉 Coupon $code applied!');
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Apply Coupon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: ctrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Enter coupon code'))),
              const SizedBox(width: 10),
              SizedBox(width: 90, child: ElevatedButton(onPressed: () => apply(ctrl.text.trim()), child: const Text('Apply'))),
            ]),
            const SizedBox(height: 16),
            if (coupons.isNotEmpty) const Text('Available offers', style: TextStyle(fontWeight: FontWeight.w600)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .45),
              child: ListView(
                shrinkWrap: true,
                children: coupons.map((c) {
                  final ok = s.itemsTotal >= c.minOrder;
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary, style: BorderStyle.solid)),
                        child: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.description ?? '', style: const TextStyle(fontSize: 12.5)),
                          if (!ok) Text('Add ${rupee(c.minOrder - s.itemsTotal)} more to unlock', style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                        ]),
                      ),
                      TextButton(onPressed: ok ? () => apply(c.code) : null, child: const Text('APPLY')),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final applied = s.coupon != null && s.couponDiscount > 0;
    return _card(Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.local_offer_outlined, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(applied ? '${s.coupon} applied' : 'Apply coupon', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(applied ? 'You saved ${rupee(s.couponDiscount)}' : (s.couponMessage ?? 'Save more on this order'),
              style: TextStyle(fontSize: 12, color: applied ? AppColors.primary : AppColors.textMuted)),
        ]),
      ),
      applied
          ? TextButton(onPressed: () => context.read<CartProvider>().removeCoupon(), child: const Text('Remove', style: TextStyle(color: AppColors.danger)))
          : TextButton(onPressed: () => _open(context), child: const Text('View offers')),
    ]));
  }
}

class BillDetails extends StatelessWidget {
  final CartSummary s;
  const BillDetails({super.key, required this.s});
  @override
  Widget build(BuildContext context) {
    Widget row(String l, String r, {Color? c, bool bold = false, String? strike}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 15.5 : 13.5))),
            if (strike != null) Text(strike, style: const TextStyle(decoration: TextDecoration.lineThrough, color: AppColors.textMuted, fontSize: 12.5)),
            const SizedBox(width: 6),
            Text(r, style: TextStyle(color: c, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : 13.5)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Bill details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 8),
      row('Items total', rupee(s.itemsTotal), strike: s.mrpTotal > s.itemsTotal ? rupee(s.mrpTotal) : null),
      if (s.couponDiscount > 0) row('Coupon discount', '-${rupee(s.couponDiscount)}', c: AppColors.primary),
      row('Delivery fee', s.deliveryFee == 0 ? 'FREE' : rupee(s.deliveryFee), c: s.deliveryFee == 0 ? AppColors.primary : null),
      if (s.handlingFee > 0) row('Handling charge', rupee(s.handlingFee)),
      const Divider(height: 18),
      row('To pay', rupee(s.grandTotal), bold: true),
    ]);
  }
}
