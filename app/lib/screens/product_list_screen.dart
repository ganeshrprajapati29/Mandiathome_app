import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/store_provider.dart';
import '../widgets/cart_bar.dart';
import '../widgets/common.dart';
import '../widgets/product_widgets.dart';
import 'category_products_screen.dart';

/// Generic list (Featured / Best sellers / Organic) with sort.
class ProductListScreen extends StatefulWidget {
  final String title;
  final bool? featured, bestSeller, organic;
  const ProductListScreen({super.key, required this.title, this.featured, this.bestSeller, this.organic});
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<Product>? _items;
  String? _error, _sort;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final r = await context
          .read<StoreProvider>()
          .products(featured: widget.featured, bestSeller: widget.bestSeller, organic: widget.organic, sort: _sort, limit: 100);
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: () async {
            final s = await pickSort(context, _sort);
            if (s == null) return;
            _sort = s.isEmpty ? null : s;
            _load();
          },
        ),
      ]),
      body: Stack(children: [
        if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (_items == null)
          const Center(child: CircularProgressIndicator())
        else if (_items!.isEmpty)
          const EmptyState(emoji: '🧺', title: 'No products', message: 'Check back soon!')
        else
          ProductGrid(products: _items!),
        const Positioned(left: 0, right: 0, bottom: 0, child: CartBar()),
      ]),
    );
  }
}
