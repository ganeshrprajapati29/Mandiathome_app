import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_bar.dart';
import '../widgets/common.dart';
import '../widgets/product_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Product>? _results;
  bool _loading = false;
  List<String> _recent = [];
  static const _popular = ['Tomato', 'Onion', 'Potato', 'Apple', 'Banana', 'Mango', 'Palak', 'Carrot', 'Ginger', 'Coriander'];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) => setState(() => _recent = sp.getStringList('recent_search') ?? []));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    q = q.trim();
    if (q.isEmpty) return setState(() => _results = null);
    setState(() => _loading = true);
    try {
      final r = await context.read<StoreProvider>().products(search: q, limit: 60);
      if (!mounted || _ctrl.text.trim() != q) return;
      setState(() => _results = r);
      final sp = await SharedPreferences.getInstance();
      _recent = [q, ..._recent.where((e) => e.toLowerCase() != q.toLowerCase())].take(8).toList();
      await sp.setStringList('recent_search', _recent);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _tapChip(String s) {
    _ctrl.text = s;
    _ctrl.selection = TextSelection.collapsed(offset: s.length);
    _search(s);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search fruits, vegetables…',
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _results = null);
                    }),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            fillColor: AppColors.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: const [SizedBox(width: 12)],
        bottom: _loading ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: Stack(children: [
        if (_results == null)
          ListView(padding: const EdgeInsets.all(16), children: [
            if (_recent.isNotEmpty) ...[
              Row(children: [
                const Expanded(child: Text('Recent searches', style: TextStyle(fontWeight: FontWeight.w700))),
                TextButton(
                  onPressed: () async {
                    (await SharedPreferences.getInstance()).remove('recent_search');
                    setState(() => _recent = []);
                  },
                  child: const Text('Clear'),
                ),
              ]),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recent.map((r) => ActionChip(avatar: const Icon(Icons.history, size: 16), label: Text(r), onPressed: () => _tapChip(r))).toList()),
              const SizedBox(height: 20),
            ],
            const Text('Popular searches', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popular
                  .map((r) => ActionChip(
                        avatar: const Icon(Icons.trending_up, size: 16, color: AppColors.primary),
                        label: Text(r),
                        backgroundColor: Colors.white,
                        onPressed: () => _tapChip(r),
                      ))
                  .toList(),
            ),
          ])
        else if (_results!.isEmpty)
          EmptyState(emoji: '🔍', title: 'No results for "${_ctrl.text}"', message: 'Try searching with a different name, e.g. "aloo" or "potato".')
        else
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            gridDelegate: productGridDelegate,
            itemCount: _results!.length,
            itemBuilder: (_, i) => ProductCard(product: _results![i]),
          ),
        const Positioned(left: 0, right: 0, bottom: 0, child: CartBar()),
      ]),
    );
  }
}
