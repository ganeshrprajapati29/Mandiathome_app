import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_bar.dart';
import '../widgets/common.dart';
import '../widgets/product_widgets.dart';
import 'search_screen.dart';

const sortOptions = {
  null: 'Relevance',
  'popular': 'Popularity',
  'price_asc': 'Price: Low to High',
  'price_desc': 'Price: High to Low',
  'rating': 'Top Rated',
  'new': 'Newest',
};

Future<String?> pickSort(BuildContext context, String? current) => showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Sort by', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          ...sortOptions.entries.map((e) => ListTile(
                title: Text(e.value),
                trailing: current == e.key ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, e.key ?? ''),
              )),
        ]),
      ),
    );

/// Category page: sub-category sidebar on the left, product grid on the right.
class CategoryProductsScreen extends StatefulWidget {
  final Category category;
  final String? initialSubId;
  const CategoryProductsScreen({super.key, required this.category, this.initialSubId});
  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  String? _sub;
  String? _sort;
  List<Product>? _products;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = widget.initialSubId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _products = null;
      _error = null;
    });
    try {
      final p = await context.read<StoreProvider>().products(category: widget.category.id, subCategory: _sub, sort: _sort, limit: 100);
      if (mounted) setState(() => _products = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = widget.category.subcategories;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
          IconButton(
            icon: Badge(isLabelVisible: _sort != null, smallSize: 8, backgroundColor: AppColors.accent, child: const Icon(Icons.sort)),
            onPressed: () async {
              final s = await pickSort(context, _sort);
              if (s == null) return;
              _sort = s.isEmpty ? null : s;
              _load();
            },
          ),
        ],
      ),
      body: Stack(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (subs.isNotEmpty)
            Container(
              width: 86,
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _SideItem(
                      label: 'All',
                      emoji: widget.category.emoji ?? '🛒',
                      image: widget.category.image,
                      color: widget.category.color,
                      selected: _sub == null,
                      onTap: () {
                        _sub = null;
                        _load();
                      }),
                  ...subs.map((s) => _SideItem(
                        label: s.name,
                        emoji: s.emoji ?? '🥬',
                        image: s.image,
                        color: s.color,
                        selected: _sub == s.id,
                        onTap: () {
                          _sub = s.id;
                          _load();
                        },
                      )),
                ],
              ),
            ),
          Expanded(child: _body()),
        ]),
        const Positioned(left: 0, right: 0, bottom: 0, child: CartBar()),
      ]),
    );
  }

  Widget _body() {
    if (_error != null) return ErrorRetry(message: _error!, onRetry: _load);
    if (_products == null) {
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 260),
        itemCount: 6,
        itemBuilder: (_, __) => const ShimmerBox(height: 200),
      );
    }
    if (_products!.isEmpty) return const EmptyState(emoji: '🧺', title: 'Nothing here yet', message: 'New stock arrives from the mandi every morning.');
    return ProductGrid(
      products: _products!,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 100),
      spacing: 10,
      onRefresh: _load,
      wrap: (i, card) => TweenAnimationBuilder<double>(
        key: ValueKey('${_sub}_${_products![i].id}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + (i % 6) * 60),
        builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 20), child: child)),
        child: card,
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final String label, emoji;
  final String? image, color;
  final bool selected;
  final VoidCallback onTap;
  const _SideItem({required this.label, required this.emoji, this.image, this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.soft : Colors.white,
          border: Border(right: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 3.5)),
        ),
        child: Column(children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: const Duration(milliseconds: 250),
            child: CategoryThumb(image: image, emoji: emoji, color: color, size: 56, circle: true),
          ),
          const SizedBox(height: 5),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11, height: 1.2, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : AppColors.text)),
        ]),
      ),
    );
  }
}
