import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/models.dart';
import '../services/api_service.dart';

class StoreProvider extends ChangeNotifier {
  final _api = Api.instance;
  HomeData? home;
  String? error;
  bool loading = false;
  Set<String> wishlist = {};

  List<Category> get categories => home?.categories ?? [];
  StoreSettings get settings => home?.settings ?? StoreSettings();

  Future<void> loadHome() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      home = HomeData.fromJson((await _api.get('/home'))['data']);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<Product>> products({String? category, String? subCategory, String? search, String? sort, bool? featured, bool? bestSeller, bool? organic, int page = 1, int limit = 40}) async {
    final q = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (category != null) 'category': category,
      if (subCategory != null) 'subCategory': subCategory,
      if (search != null && search.isNotEmpty) 'search': search,
      if (sort != null) 'sort': sort,
      if (featured == true) 'featured': 'true',
      if (bestSeller == true) 'bestSeller': 'true',
      if (organic == true) 'organic': 'true',
    };
    final r = await _api.get('/products?${Uri(queryParameters: q).query}');
    return (r['data'] as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<(Product, List<Product>)> product(String id) async {
    final r = await _api.get('/products/$id');
    return (Product.fromJson(r['data']), (r['similar'] as List? ?? []).map((e) => Product.fromJson(e)).toList());
  }

  Future<List<Coupon>> coupons() async => ((await _api.get('/coupons'))['data'] as List).map((e) => Coupon.fromJson(e)).toList();

  // ---------- wishlist ----------
  Future<void> loadWishlist() async {
    if (!_api.hasToken) {
      wishlist = {};
      notifyListeners();
      return;
    }
    try {
      final r = await _api.get('/auth/me');
      wishlist = ((r['user']['wishlist'] as List?) ?? []).map((e) => '$e').toSet();
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Product>> wishlistProducts() async => ((await _api.get('/user/wishlist'))['data'] as List).map((e) => Product.fromJson(e)).toList();

  Future<void> toggleWishlist(String productId) async {
    final had = wishlist.contains(productId);
    had ? wishlist.remove(productId) : wishlist.add(productId);
    notifyListeners();
    try {
      await _api.post('/user/wishlist/$productId');
    } catch (e) {
      had ? wishlist.add(productId) : wishlist.remove(productId);
      notifyListeners();
      rethrow;
    }
  }

  // ---------- orders ----------
  Future<List<Order>> orders() async => ((await _api.get('/orders?limit=50'))['data'] as List).map((e) => Order.fromJson(e)).toList();
  Future<Order> order(String id) async => Order.fromJson((await _api.get('/orders/$id'))['data']);
  Future<Order> placeOrder({required String addressId, required String paymentMethod, required String date, required String slot, String? note}) async =>
      Order.fromJson((await _api.post('/orders', {
        'addressId': addressId,
        'paymentMethod': paymentMethod,
        'deliverySlot': {'date': date, 'slot': slot},
        'note': note,
      }))['data']);
  Future<Order> cancelOrder(String id, String reason) async => Order.fromJson((await _api.post('/orders/$id/cancel', {'reason': reason}))['data']);
}
