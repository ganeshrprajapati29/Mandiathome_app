import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_bar.dart';
import '../widgets/common.dart';
import 'category_products_screen.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreProvider>();
    final cats = store.categories;
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())))
        ],
      ),
      body: Stack(children: [
        if (cats.isEmpty && store.loading)
          const Center(child: CircularProgressIndicator())
        else if (cats.isEmpty)
          ErrorRetry(message: store.error ?? 'No categories found', onRetry: store.loadHome)
        else
          RefreshIndicator(
            onRefresh: store.loadHome,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: cats.length,
              itemBuilder: (_, i) => _CategoryBlock(category: cats[i], index: i),
            ),
          ),
        const Positioned(left: 0, right: 0, bottom: 0, child: CartBar()),
      ]),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  final Category category;
  final int index;
  const _CategoryBlock({required this.category, required this.index});
  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(category.color);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 120),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 30), child: child)),
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: category))),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text(category.emoji ?? '🥬', style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(category.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${category.subcategories.length} sub-categories', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
            ]),
          ),
          if (category.subcategories.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .74),
              itemCount: category.subcategories.length,
              itemBuilder: (_, i) {
                final s = category.subcategories[i];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(category: category, initialSubId: s.id))),
                  child: Column(children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.fromHex(s.color), borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.center,
                        child: (s.image ?? '').isNotEmpty
                            ? ProductImage(url: s.image, emoji: s.emoji, size: 50)
                            : Text(s.emoji ?? '🥬', style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(s.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.2)),
                  ]),
                );
              },
            ),
          ],
        ]),
      ),
    );
  }
}
