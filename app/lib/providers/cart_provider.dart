import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/models.dart';
import '../services/api_service.dart';

class CartProvider extends ChangeNotifier {
  final _api = Api.instance;
  CartSummary summary = CartSummary();
  final Map<String, int> _qty = {}; // "productId|variantId" -> qty (optimistic)
  final Set<String> _busy = {};
  bool loading = false;

  static String key(String p, String v) => '$p|$v';
  int qtyOf(String productId, String variantId) => _qty[key(productId, variantId)] ?? 0;
  int qtyOfProduct(String productId) => _qty.entries.where((e) => e.key.startsWith('$productId|')).fold(0, (s, e) => s + e.value);
  bool isBusy(String productId, String variantId) => _busy.contains(key(productId, variantId));
  int get count => summary.count;
  bool get isEmpty => summary.items.isEmpty;

  void _apply(dynamic data) {
    summary = CartSummary.fromJson(data);
    _qty
      ..clear()
      ..addEntries(summary.items.map((i) => MapEntry(key(i.productId, i.variantId), i.qty)));
    notifyListeners();
  }

  Future<void> load() async {
    if (!_api.hasToken) return reset();
    loading = true;
    notifyListeners();
    try {
      _apply((await _api.get('/cart'))['data']);
    } catch (_) {
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void reset() {
    summary = CartSummary();
    _qty.clear();
    notifyListeners();
  }

  /// Sets the quantity of one product variant (0 removes). Optimistic UI with rollback.
  Future<void> setQty(String productId, String variantId, int qty) async {
    final k = key(productId, variantId);
    final prev = _qty[k] ?? 0;
    if (qty <= 0) {
      _qty.remove(k);
    } else {
      _qty[k] = qty;
    }
    _busy.add(k);
    notifyListeners();
    try {
      _apply((await _api.post('/cart', {'productId': productId, 'variantId': variantId, 'qty': qty}))['data']);
    } catch (e) {
      if (prev == 0) {
        _qty.remove(k);
      } else {
        _qty[k] = prev;
      }
      rethrow;
    } finally {
      _busy.remove(k);
      notifyListeners();
    }
  }

  Future<void> applyCoupon(String code) async => _apply((await _api.post('/cart/coupon', {'code': code}))['data']);
  Future<void> removeCoupon() async => _apply((await _api.delete('/cart/coupon'))['data']);
  Future<void> clear() async => _apply((await _api.delete('/cart'))['data']);
}
