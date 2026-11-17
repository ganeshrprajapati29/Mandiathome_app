import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_bar.dart';
import '../widgets/common.dart';
import '../widgets/product_widgets.dart';
import 'address_screens.dart';
import 'category_products_screen.dart';
import 'product_list_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    final home = store.home;
    return Scaffold(
      body: Stack(children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([store.loadHome(), context.read<CartProvider>().load()]);
          },
          child: CustomScrollView(slivers: [
            const _HomeHeader(),
            if (home == null && store.loading) const SliverToBoxAdapter(child: _HomeSkeleton()),
            if (home == null && store.error != null)
              SliverFillRemaining(hasScrollBody: false, child: ErrorRetry(message: store.error!, onRetry: store.loadHome)),
            if (home != null) ...[
              if (!home.settings.isStoreOpen)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14)),
                    child: const Text('⏰ We are currently closed. You can browse and order once we open.', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
              if (home.banners.isNotEmpty) SliverToBoxAdapter(child: _BannerCarousel(banners: home.banners)),
              SliverToBoxAdapter(child: _InfoStrip(settings: home.settings)),
              const SliverToBoxAdapter(child: SectionHeader(title: 'Shop by Category', subtitle: 'Fresh picks across the mandi')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 10, childAspectRatio: .72),
                  delegate: SliverChildBuilderDelegate((_, i) => _CategoryTile(category: _subcats(home)[i]), childCount: _subcats(home).length.clamp(0, 12)),
                ),
              ),
              if (home.featured.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: '⭐ Fresh Picks For You',
                    subtitle: 'Handpicked today',
                    onSeeAll: () => _openList(context, 'Fresh Picks For You', featured: true),
                  ),
                ),
                SliverToBoxAdapter(child: ProductRail(products: home.featured)),
              ],
              if (home.bestSellers.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(title: '🔥 Best Sellers', subtitle: 'Most loved by our customers', onSeeAll: () => _openList(context, 'Best Sellers', bestSeller: true)),
                ),
                SliverToBoxAdapter(child: ProductRail(products: home.bestSellers)),
              ],
              const SliverToBoxAdapter(child: _PromoCard()),
              for (final s in home.sections) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: '${s.category.emoji ?? ''} ${s.category.name}',
                    onSeeAll: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: home.categories.firstWhere((c) => c.id == s.category.id)))),
                  ),
                ),
                SliverToBoxAdapter(child: ProductRail(products: s.products)),
              ],
              if (home.organic.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionHeader(title: '🌿 Go Organic', subtitle: 'Chemical-free & healthy', onSeeAll: () => _openList(context, 'Organic', organic: true))),
                SliverToBoxAdapter(child: ProductRail(products: home.organic)),
              ],
              const SliverToBoxAdapter(child: _Footer()),
            ],
          ]),
        ),
        const Positioned(left: 0, right: 0, bottom: 0, child: CartBar()),
      ]),
    );
  }

  /// Home grid shows sub-categories (more specific & visual), falling back to top-level.
  List<Category> _subcats(HomeData h) {
    final subs = [for (final c in h.categories) ...c.subcategories];
    return subs.isEmpty ? h.categories : subs;
  }

  void _openList(BuildContext context, String title, {bool? featured, bool? bestSeller, bool? organic}) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductListScreen(title: title, featured: featured, bestSeller: bestSeller, organic: organic)));
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final addr = auth.defaultAddress;
    return SliverAppBar(
      pinned: true,
      floating: false,
      toolbarHeight: 66,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.primaryDark,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.greenGradient)),
      titleSpacing: 16,
      title: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () async {
              if (await requireLogin(context) && context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressListScreen()));
              }
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.bolt, color: AppColors.yellow, size: 20),
                Text('Delivery in 30–45 mins', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                  child: Text(
                    addr != null ? '${addr.label} • ${addr.full}' : 'Set your delivery location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w400),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 18),
              ]),
            ]),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/images/logo.png', width: 40, height: 40)),
        ),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: const Row(children: [
                Icon(Icons.search, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(child: _RotatingHint()),
                Icon(Icons.mic_none, color: AppColors.textMuted),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RotatingHint extends StatefulWidget {
  const _RotatingHint();
  @override
  State<_RotatingHint> createState() => _RotatingHintState();
}

class _RotatingHintState extends State<_RotatingHint> {
  static const _hints = ['"tomato"', '"aloo"', '"apple"', '"palak"', '"mango"', '"onion"'];
  int _i = 0;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2200), (_) => setState(() => _i = (_i + 1) % _hints.length));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        const Text('Search ', style: TextStyle(color: AppColors.textMuted)),
        Expanded(
          child: ClipRect(
            child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (c, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: Align(
              key: ValueKey(_i),
              alignment: Alignment.centerLeft,
              child: Text(_hints[_i], style: const TextStyle(color: AppColors.textMuted)),
            ),
          ),
          ),
        ),
      ]);
}

class _BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;
  const _BannerCarousel({required this.banners});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pc = PageController(viewportFraction: .9);
  int _page = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_pc.hasClients || widget.banners.length < 2) return;
      _pc.animateToPage((_page + 1) % widget.banners.length, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.read<StoreProvider>().categories;
    return Column(children: [
      const SizedBox(height: 14),
      SizedBox(
        height: 150,
        child: PageView.builder(
          controller: _pc,
          itemCount: widget.banners.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) {
            final b = widget.banners[i];
            final color = AppColors.fromHex(b.bgColor, AppColors.primary);
            return AnimatedScale(
              scale: _page == i ? 1 : .94,
              duration: const Duration(milliseconds: 300),
              child: GestureDetector(
                onTap: () {
                  final c = cats.where((c) => c.id == b.categoryId);
                  if (c.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: c.first)));
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, .25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    image: (b.image ?? '').isNotEmpty ? DecorationImage(image: NetworkImage(ApiConfig.image(b.image)), fit: BoxFit.cover) : null,
                  ),
                  child: (b.image ?? '').isNotEmpty
                      ? null
                      : Stack(children: [
                          Positioned(right: -20, bottom: -20, child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withOpacity(.12))),
                          Positioned(right: 18, top: 0, bottom: 0, child: Center(child: Text(b.emoji ?? '🥬', style: const TextStyle(fontSize: 72)))),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 120, 18),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(b.title, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.15)),
                              const SizedBox(height: 6),
                              if (b.subtitle != null) Text(b.subtitle!, maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                child: Text('Order now', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            ]),
                          ),
                        ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.banners.length,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _page == i ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: _page == i ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    ]);
  }
}

class _InfoStrip extends StatelessWidget {
  final StoreSettings settings;
  const _InfoStrip({required this.settings});
  @override
  Widget build(BuildContext context) {
    Widget chip(String e, String t, String s) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Text(e, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ]),
              ),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(children: [
        chip('🚚', 'Free Delivery', 'Above ${rupee(settings.freeDeliveryAbove)}'),
        const SizedBox(width: 8),
        chip('🌾', 'Mandi Fresh', 'Picked daily'),
        const SizedBox(width: 8),
        chip('💵', 'Cash on', 'Delivery'),
      ]),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  const _CategoryTile({required this.category});
  @override
  Widget build(BuildContext context) {
    final store = context.read<StoreProvider>();
    return GestureDetector(
      onTap: () {
        final parent = category.parentId == null ? category : store.categories.firstWhere((c) => c.id == category.parentId, orElse: () => category);
        Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: parent, initialSubId: category.parentId == null ? null : category.id)));
      },
      child: Column(children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.fromHex(category.color), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: (category.image ?? '').isNotEmpty
                ? ProductImage(url: category.image, emoji: category.emoji, size: 56)
                : Text(category.emoji ?? '🥬', style: const TextStyle(fontSize: 34)),
          ),
        ),
        const SizedBox(height: 6),
        Text(category.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
      ]),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard();
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('First order? 🎉', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
              SizedBox(height: 4),
              Text('Get flat ₹50 OFF with code FRESH50', style: TextStyle(fontWeight: FontWeight.w500)),
            ]),
          ),
          Text('🧺', style: TextStyle(fontSize: 52)),
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 110),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Mandi fresh,\nat your home.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.grey.shade300, height: 1.1)),
          const SizedBox(height: 8),
          Text('Made with ❤️ for fresh food lovers', style: TextStyle(color: Colors.grey.shade400)),
        ]),
      );
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const ShimmerBox(height: 150, radius: 20),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: List.generate(8, (_) => const ShimmerBox(height: 70)),
          ),
          const SizedBox(height: 20),
          Row(children: List.generate(2, (_) => const Expanded(child: Padding(padding: EdgeInsets.all(6), child: ShimmerBox(height: 220))))),
        ]),
      );
}
