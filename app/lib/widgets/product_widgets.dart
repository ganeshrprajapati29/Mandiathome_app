import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../screens/product_detail_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// "ADD" button that turns into a − qty + stepper. Handles login + errors.
class AddToCartButton extends StatelessWidget {
  final Product product;
  final Variant variant;
  final double height;
  final bool expanded;
  const AddToCartButton({super.key, required this.product, required this.variant, this.height = 34, this.expanded = false});

  Future<void> _set(BuildContext context, int q) async {
    if (!await requireLogin(context)) return;
    if (!context.mounted) return;
    try {
      await context.read<CartProvider>().setQty(product.id, variant.id, q);
    } catch (e) {
      if (context.mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.qtyOf(product.id, variant.id);
    final width = expanded ? double.infinity : 84.0;

    if (!variant.inStock) {
      return Container(
        height: height,
        width: width,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: const Text('Sold out', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: qty == 0
          ? SizedBox(
              key: const ValueKey('add'),
              height: height,
              width: width,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, height),
                  padding: EdgeInsets.zero,
                  backgroundColor: const Color(0xFFF1F8F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
                onPressed: () => _set(context, 1),
                child: Text('ADD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: height > 40 ? 16 : 13, letterSpacing: .5)),
              ),
            )
          : Container(
              key: const ValueKey('stepper'),
              height: height,
              width: width,
              decoration: BoxDecoration(gradient: AppColors.greenGradient, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                _StepBtn(icon: Icons.remove, onTap: () => _set(context, qty - 1)),
                Expanded(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (c, a) => SlideTransition(
                          position: Tween(begin: const Offset(0, .5), end: Offset.zero).animate(a), child: FadeTransition(opacity: a, child: c)),
                      child:
                          Text('$qty', key: ValueKey(qty), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: height > 40 ? 17 : 14)),
                    ),
                  ),
                ),
                _StepBtn(
                  icon: Icons.add,
                  onTap: () {
                    if (qty >= variant.maxPerOrder || qty >= variant.stock) {
                      showSnack(context, 'Maximum quantity reached for this item', error: true);
                      return;
                    }
                    _set(context, qty + 1);
                  },
                ),
              ]),
            ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Icon(icon, color: Colors.white, size: 18)),
      );
}

/// Bottom sheet listing all pack sizes (250 g / 500 g / 1 kg ...) with their prices.
Future<void> showVariantSheet(BuildContext context, Product p) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Row(children: [
            ProductImage(url: p.image, emoji: p.emoji, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Text('Choose a pack size', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          ...p.variants.map((v) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(v.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (v.discount > 0) ...[const SizedBox(width: 8), DiscountBadge(v.discount)],
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        PriceText(price: v.price, mrp: v.mrp, size: 14),
                        if (v.perUnitHint != null) Text('  (${v.perUnitHint})', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ]),
                    ]),
                  ),
                  AddToCartButton(product: p, variant: v),
                ]),
              )),
        ]),
      ),
    ),
  );
}

/// Grid / rail product card.
class ProductCard extends StatelessWidget {
  final Product product;
  final double? width;
  const ProductCard({super.key, required this.product, this.width});

  @override
  Widget build(BuildContext context) {
    final v = product.defaultVariant;
    final multi = product.variants.length > 1;
    final wish = context.select<StoreProvider, bool>((s) => s.wishlist.contains(product.id));
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product.id, initial: product))),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            LayoutBuilder(builder: (_, c) => ProductImage(url: product.image, emoji: product.emoji, size: c.maxWidth, radius: 14)),
            if (v.discount > 0) Positioned(left: 0, top: 0, child: DiscountBadge(v.discount)),
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                onTap: () async {
                  if (!await requireLogin(context)) return;
                  if (!context.mounted) return;
                  context.read<StoreProvider>().toggleWishlist(product.id).catchError((e) {
                    if (context.mounted) showSnack(context, e.toString(), error: true);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.9), shape: BoxShape.circle),
                  child: Icon(wish ? Icons.favorite : Icons.favorite_border, size: 17, color: wish ? AppColors.accent : AppColors.textMuted),
                ),
              ),
            ),
            if (product.isOrganic)
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                  child: const Text('🌿 Organic', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.2)),
          if (product.hindiName != null) Text(product.hindiName!, maxLines: 1, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: multi ? () => showVariantSheet(context, product) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(v.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                if (multi) const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.primary),
              ]),
            ),
          ),
          const Spacer(),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rupee(v.price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (v.mrp > v.price)
                  Text(rupee(v.mrp), style: const TextStyle(fontSize: 11, color: AppColors.textMuted, decoration: TextDecoration.lineThrough)),
              ]),
            ),
            multi ? _MultiAdd(product: product) : AddToCartButton(product: product, variant: v, height: 32).sized(76),
          ]),
        ]),
      ),
    );
  }
}

extension on Widget {
  Widget sized(double w) => SizedBox(width: w, child: this);
}

/// For multi-variant products: ADD opens the pack-size sheet, shows total qty in cart.
class _MultiAdd extends StatelessWidget {
  final Product product;
  const _MultiAdd({required this.product});
  @override
  Widget build(BuildContext context) {
    final q = context.select<CartProvider, int>((c) => c.qtyOfProduct(product.id));
    if (!product.inStock) return AddToCartButton(product: product, variant: product.defaultVariant, height: 32).sized(76);
    return GestureDetector(
      onTap: () => showVariantSheet(context, product),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 32,
        width: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: q > 0 ? AppColors.greenGradient : null,
          color: q > 0 ? null : const Color(0xFFF1F8F1),
          border: Border.all(color: AppColors.primary, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(q > 0 ? '$q in cart' : 'ADD',
            style: TextStyle(color: q > 0 ? Colors.white : AppColors.primary, fontWeight: FontWeight.w700, fontSize: q > 0 ? 11.5 : 13)),
      ),
    );
  }
}

/// Horizontal product rail.
class ProductRail extends StatelessWidget {
  final List<Product> products;
  const ProductRail({super.key, required this.products});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 262,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => ProductCard(product: products[i], width: 150),
        ),
      );
}

const productGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .60);
