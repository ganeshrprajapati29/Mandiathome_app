import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_widgets.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final Product? initial;
  const ProductDetailScreen({super.key, required this.productId, this.initial});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _p;
  List<Product> _similar = [];
  String? _variantId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _p = widget.initial;
    _variantId = _p?.defaultVariant.id;
    _load();
  }

  Future<void> _load() async {
    try {
      final (p, sim) = await context.read<StoreProvider>().product(widget.productId);
      if (!mounted) return;
      setState(() {
        _p = p;
        _similar = sim;
        if (_variantId == null || !p.variants.any((v) => v.id == _variantId)) _variantId = p.defaultVariant.id;
      });
    } catch (e) {
      if (mounted && _p == null) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_p == null) {
      return Scaffold(appBar: AppBar(), body: _error != null ? ErrorRetry(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()));
    }
    final p = _p!;
    final v = p.variants.firstWhere((x) => x.id == _variantId, orElse: () => p.defaultVariant);
    final wish = context.select<StoreProvider, bool>((s) => s.wishlist.contains(p.id));
    final cartCount = context.select<CartProvider, int>((c) => c.count);
    final cat = context.read<StoreProvider>().categories.where((c) => c.id == p.categoryId);
    final bg = cat.isNotEmpty ? AppColors.fromHex(cat.first.color) : AppColors.soft;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 330,
          backgroundColor: Colors.white,
          leading: _circleBtn(Icons.arrow_back, () => Navigator.pop(context)),
          actions: [
            _circleBtn(wish ? Icons.favorite : Icons.favorite_border, () async {
              if (!await requireLogin(context) || !context.mounted) return;
              context.read<StoreProvider>().toggleWishlist(p.id).then((_) {
                if (context.mounted) showSnack(context, wish ? 'Removed from wishlist' : 'Added to wishlist ❤️');
              }).catchError((e) {
                if (context.mounted) showSnack(context, e.toString(), error: true);
              });
            }, color: wish ? AppColors.accent : null),
            _circleBtn(Icons.shopping_bag_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())), badge: cartCount),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [bg, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              padding: const EdgeInsets.only(top: 70, bottom: 10),
              alignment: Alignment.center,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: .7, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: ProductImage(url: p.image, emoji: p.emoji, size: 230, radius: 28, bg: Colors.white),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (p.isOrganic) _tag('🌿 Organic', AppColors.primary),
                if (p.isBestSeller) _tag('🔥 Best seller', AppColors.orange),
                if (p.subCategoryName != null) _tag(p.subCategoryName!, AppColors.textMuted),
              ]),
              const SizedBox(height: 10),
              Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2)),
              if (p.hindiName != null) Text(p.hindiName!, style: const TextStyle(fontSize: 15, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text(p.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    const Icon(Icons.star, color: Colors.white, size: 13),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('${p.ratingCount} ratings', style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ]),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(rupee(v.price), key: ValueKey(v.id), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                if (v.mrp > v.price)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('MRP ${rupee(v.mrp)}', style: const TextStyle(color: AppColors.textMuted, decoration: TextDecoration.lineThrough)),
                  ),
                const SizedBox(width: 8),
                if (v.discount > 0) Padding(padding: const EdgeInsets.only(bottom: 5), child: DiscountBadge(v.discount)),
              ]),
              Text('${v.label}${v.perUnitHint != null ? '  •  ${v.perUnitHint}' : ''}  •  Inclusive of all taxes',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 20),
              const Text('Select pack size', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 92,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: p.variants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final x = p.variants[i];
                final sel = x.id == v.id;
                final inCart = context.select<CartProvider, int>((c) => c.qtyOf(p.id, x.id));
                return GestureDetector(
                  onTap: () => setState(() => _variantId = x.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 112,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.soft : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.8 : 1),
                    ),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(x.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(rupee(x.price), style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (x.discount > 0)
                          Text('${x.discount}% off', style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600))
                        else if (!x.inStock)
                          const Text('Sold out', style: TextStyle(color: AppColors.danger, fontSize: 11)),
                      ]),
                      if (inCart > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.primary,
                              child: Text('$inCart', style: const TextStyle(color: Colors.white, fontSize: 10))),
                        ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              _features(),
              const SizedBox(height: 14),
              if ((p.description ?? '').isNotEmpty) _info('About this product', Icons.info_outline, p.description!, initiallyExpanded: true),
              if ((p.storageTips ?? '').isNotEmpty) _info('Storage tips', Icons.kitchen_outlined, p.storageTips!),
              _info('Details', Icons.list_alt,
                  ['Origin: ${p.origin ?? 'Local mandi'}', 'Shelf life: ${p.shelfLife ?? '2-4 days'}', 'Unit: ${v.label}'].join('\n')),
            ]),
          ),
        ),
        if (_similar.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionHeader(title: 'You might also like')),
          SliverToBoxAdapter(child: ProductRail(products: _similar)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ]),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
        decoration:
            BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, -4))]),
        child: Row(children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              PriceText(price: v.price, mrp: v.mrp, size: 18),
            ]),
          ),
          Expanded(child: AddToCartButton(product: p, variant: v, height: 50, expanded: true)),
        ]),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color? color, int badge = 0}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  backgroundColor: AppColors.accent,
                  child: Icon(icon, size: 21, color: color ?? AppColors.text)),
            ),
          ),
        ),
      );

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );

  Widget _features() {
    Widget f(String e, String t) => Expanded(
          child: Column(children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(height: 6),
            Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
        );
    return Row(children: [f('🌾', 'Mandi\nFresh'), f('🧼', 'Cleaned &\nSorted'), f('🔄', 'Easy\nReturns'), f('🚚', 'Fast\nDelivery')]);
  }

  Widget _info(String title, IconData icon, String body, {bool initiallyExpanded = false}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            leading: Icon(icon, color: AppColors.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedAlignment: Alignment.centerLeft,
            children: [Text(body, style: const TextStyle(color: AppColors.textMuted, height: 1.5))],
          ),
        ),
      );
}
