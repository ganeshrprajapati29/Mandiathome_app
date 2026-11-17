// Plain data models mapped from the REST API.

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _id(dynamic v) => v is Map ? (v['_id'] ?? '').toString() : (v ?? '').toString();

class Category {
  final String id, name;
  final String? emoji, image, color, parentId;
  final List<Category> subcategories;
  Category({required this.id, required this.name, this.emoji, this.image, this.color, this.parentId, this.subcategories = const []});
  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: _id(j['_id']),
        name: j['name'] ?? '',
        emoji: j['emoji'],
        image: j['image'],
        color: j['color'],
        parentId: j['parent'] == null ? null : _id(j['parent']),
        subcategories: (j['subcategories'] as List? ?? []).map((e) => Category.fromJson(e)).toList(),
      );
}

class Variant {
  final String id, label, unit;
  final double quantity, mrp, price;
  final int stock, maxPerOrder;
  final bool isDefault;
  Variant({required this.id, required this.label, required this.unit, required this.quantity, required this.mrp, required this.price, required this.stock, required this.maxPerOrder, required this.isDefault});
  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
        id: _id(j['_id']),
        label: j['label'] ?? '',
        unit: j['unit'] ?? '',
        quantity: _d(j['quantity']),
        mrp: _d(j['mrp']),
        price: _d(j['price']),
        stock: _i(j['stock']),
        maxPerOrder: j['maxPerOrder'] == null ? 10 : _i(j['maxPerOrder']),
        isDefault: j['isDefault'] == true,
      );
  int get discount => mrp > price && mrp > 0 ? (((mrp - price) / mrp) * 100).round() : 0;
  bool get inStock => stock > 0;

  /// Price per kg / per litre hint shown under price, e.g. "₹48/kg"
  String? get perUnitHint {
    if (unit == 'g' && quantity > 0) return '₹${(price / quantity * 1000).round()}/kg';
    if (unit == 'kg' && quantity > 1) return '₹${(price / quantity).round()}/kg';
    if (unit == 'ml' && quantity > 0) return '₹${(price / quantity * 1000).round()}/L';
    return null;
  }
}

class Product {
  final String id, name;
  final String? hindiName, description, emoji, origin, shelfLife, storageTips, categoryName, subCategoryName, categoryId, subCategoryId;
  final List<String> images, tags;
  final List<Variant> variants;
  final bool isOrganic, isFeatured, isBestSeller;
  final double rating;
  final int ratingCount;
  Product({
    required this.id, required this.name, this.hindiName, this.description, this.emoji, this.origin, this.shelfLife, this.storageTips,
    this.categoryName, this.subCategoryName, this.categoryId, this.subCategoryId,
    this.images = const [], this.tags = const [], required this.variants,
    this.isOrganic = false, this.isFeatured = false, this.isBestSeller = false, this.rating = 0, this.ratingCount = 0,
  });
  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: _id(j['_id']),
        name: j['name'] ?? '',
        hindiName: j['hindiName'],
        description: j['description'],
        emoji: j['emoji'],
        origin: j['origin'],
        shelfLife: j['shelfLife'],
        storageTips: j['storageTips'],
        categoryId: _id(j['category']),
        subCategoryId: j['subCategory'] == null ? null : _id(j['subCategory']),
        categoryName: j['category'] is Map ? j['category']['name'] : null,
        subCategoryName: j['subCategory'] is Map ? j['subCategory']['name'] : null,
        images: (j['images'] as List? ?? []).map((e) => '$e').toList(),
        tags: (j['tags'] as List? ?? []).map((e) => '$e').toList(),
        variants: (j['variants'] as List? ?? []).map((e) => Variant.fromJson(e)).toList(),
        isOrganic: j['isOrganic'] == true,
        isFeatured: j['isFeatured'] == true,
        isBestSeller: j['isBestSeller'] == true,
        rating: _d(j['rating']),
        ratingCount: _i(j['ratingCount']),
      );
  Variant get defaultVariant => variants.firstWhere((v) => v.isDefault, orElse: () => variants.first);
  bool get inStock => variants.any((v) => v.inStock);
  String? get image => images.isNotEmpty ? images.first : null;
}

class BannerItem {
  final String id, title;
  final String? subtitle, image, emoji, bgColor, categoryId;
  BannerItem({required this.id, required this.title, this.subtitle, this.image, this.emoji, this.bgColor, this.categoryId});
  factory BannerItem.fromJson(Map<String, dynamic> j) => BannerItem(
        id: _id(j['_id']), title: j['title'] ?? '', subtitle: j['subtitle'], image: j['image'], emoji: j['emoji'], bgColor: j['bgColor'],
        categoryId: j['category'] == null ? null : _id(j['category']),
      );
}

class StoreSettings {
  final double deliveryFee, freeDeliveryAbove, minOrderAmount;
  final List<String> deliverySlots;
  final bool codEnabled, isStoreOpen;
  final String supportPhone, supportEmail;
  StoreSettings({this.deliveryFee = 30, this.freeDeliveryAbove = 299, this.minOrderAmount = 99, this.deliverySlots = const [], this.codEnabled = true, this.isStoreOpen = true, this.supportPhone = '', this.supportEmail = ''});
  factory StoreSettings.fromJson(Map<String, dynamic> j) => StoreSettings(
        deliveryFee: _d(j['deliveryFee']),
        freeDeliveryAbove: _d(j['freeDeliveryAbove']),
        minOrderAmount: _d(j['minOrderAmount']),
        deliverySlots: (j['deliverySlots'] as List? ?? []).map((e) => '$e').toList(),
        codEnabled: j['codEnabled'] != false,
        isStoreOpen: j['isStoreOpen'] != false,
        supportPhone: j['supportPhone'] ?? '',
        supportEmail: j['supportEmail'] ?? '',
      );
}

class HomeSection {
  final Category category;
  final List<Product> products;
  HomeSection(this.category, this.products);
}

class HomeData {
  final List<BannerItem> banners;
  final List<Category> categories;
  final List<Product> featured, bestSellers, organic;
  final List<HomeSection> sections;
  final StoreSettings settings;
  HomeData({required this.banners, required this.categories, required this.featured, required this.bestSellers, required this.organic, required this.sections, required this.settings});
  factory HomeData.fromJson(Map<String, dynamic> j) {
    List<Product> p(String k) => (j[k] as List? ?? []).map((e) => Product.fromJson(e)).toList();
    return HomeData(
      banners: (j['banners'] as List? ?? []).map((e) => BannerItem.fromJson(e)).toList(),
      categories: (j['categories'] as List? ?? []).map((e) => Category.fromJson(e)).toList(),
      featured: p('featured'),
      bestSellers: p('bestSellers'),
      organic: p('organic'),
      sections: (j['sections'] as List? ?? [])
          .map((s) => HomeSection(Category.fromJson(s['category']), (s['products'] as List).map((e) => Product.fromJson(e)).toList()))
          .toList(),
      settings: StoreSettings.fromJson(j['settings'] ?? {}),
    );
  }
}

class CartLine {
  final String productId, variantId, name, variantLabel;
  final String? emoji, image;
  final double price, mrp, total;
  final int qty, stock, maxPerOrder;
  CartLine({required this.productId, required this.variantId, required this.name, required this.variantLabel, this.emoji, this.image, required this.price, required this.mrp, required this.total, required this.qty, required this.stock, required this.maxPerOrder});
  factory CartLine.fromJson(Map<String, dynamic> j) {
    final p = j['product'] ?? {};
    final v = j['variant'] ?? {};
    final imgs = (p['images'] as List? ?? []);
    return CartLine(
      productId: _id(p['_id']), variantId: _id(v['_id']), name: p['name'] ?? '', variantLabel: v['label'] ?? '',
      emoji: p['emoji'], image: imgs.isNotEmpty ? '${imgs.first}' : null,
      price: _d(v['price']), mrp: _d(v['mrp']), total: _d(j['total']), qty: _i(j['qty']), stock: _i(v['stock']), maxPerOrder: _i(v['maxPerOrder']),
    );
  }
}

class CartSummary {
  final List<CartLine> items;
  final int count;
  final double itemsTotal, mrpTotal, savings, couponDiscount, deliveryFee, handlingFee, grandTotal, freeDeliveryAbove, amountForFreeDelivery, minOrderAmount;
  final String? coupon, couponMessage;
  final List<String> warnings;
  CartSummary({this.items = const [], this.count = 0, this.itemsTotal = 0, this.mrpTotal = 0, this.savings = 0, this.couponDiscount = 0, this.deliveryFee = 0, this.handlingFee = 0, this.grandTotal = 0, this.freeDeliveryAbove = 0, this.amountForFreeDelivery = 0, this.minOrderAmount = 0, this.coupon, this.couponMessage, this.warnings = const []});
  factory CartSummary.fromJson(Map<String, dynamic> j) => CartSummary(
        items: (j['items'] as List? ?? []).map((e) => CartLine.fromJson(e)).toList(),
        count: _i(j['count']),
        itemsTotal: _d(j['itemsTotal']),
        mrpTotal: _d(j['mrpTotal']),
        savings: _d(j['savings']),
        couponDiscount: _d(j['couponDiscount']),
        deliveryFee: _d(j['deliveryFee']),
        handlingFee: _d(j['handlingFee']),
        grandTotal: _d(j['grandTotal']),
        freeDeliveryAbove: _d(j['freeDeliveryAbove']),
        amountForFreeDelivery: _d(j['amountForFreeDelivery']),
        minOrderAmount: _d(j['minOrderAmount']),
        coupon: j['coupon'],
        couponMessage: j['couponMessage'],
        warnings: (j['warnings'] as List? ?? []).map((e) => '$e').toList(),
      );
}

class Address {
  final String id, label, name, phone, line1, city, pincode;
  final String? line2, landmark, state;
  final bool isDefault;
  Address({required this.id, required this.label, required this.name, required this.phone, required this.line1, required this.city, required this.pincode, this.line2, this.landmark, this.state, this.isDefault = false});
  factory Address.fromJson(Map<String, dynamic> j) => Address(
        id: _id(j['_id']), label: j['label'] ?? 'Home', name: j['name'] ?? '', phone: j['phone'] ?? '', line1: j['line1'] ?? '',
        city: j['city'] ?? '', pincode: j['pincode'] ?? '', line2: j['line2'], landmark: j['landmark'], state: j['state'], isDefault: j['isDefault'] == true,
      );
  Map<String, dynamic> toJson() => {
        'label': label, 'name': name, 'phone': phone, 'line1': line1, 'line2': line2, 'landmark': landmark, 'city': city, 'state': state, 'pincode': pincode, 'isDefault': isDefault,
      };
  String get full => [line1, line2, landmark, '$city - $pincode'].where((e) => e != null && e.isNotEmpty).join(', ');
}

class OrderItem {
  final String name, variantLabel;
  final String? emoji, image;
  final double price, mrp, total;
  final int qty;
  OrderItem({required this.name, required this.variantLabel, this.emoji, this.image, required this.price, required this.mrp, required this.total, required this.qty});
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        name: j['name'] ?? '', variantLabel: j['variantLabel'] ?? '', emoji: j['emoji'], image: j['image'],
        price: _d(j['price']), mrp: _d(j['mrp']), total: _d(j['total']), qty: _i(j['qty']),
      );
}

class StatusEvent {
  final String status;
  final String? note;
  final DateTime at;
  StatusEvent(this.status, this.note, this.at);
}

class Order {
  final String id, orderNo, status, paymentMethod, paymentStatus;
  final List<OrderItem> items;
  final Address? address;
  final double itemsTotal, mrpTotal, savings, couponDiscount, deliveryFee, handlingFee, grandTotal;
  final String? couponCode, slotDate, slot, cancelReason;
  final DateTime createdAt;
  final List<StatusEvent> history;
  Order({required this.id, required this.orderNo, required this.status, required this.paymentMethod, required this.paymentStatus, required this.items, this.address, required this.itemsTotal, required this.mrpTotal, required this.savings, required this.couponDiscount, required this.deliveryFee, required this.handlingFee, required this.grandTotal, this.couponCode, this.slotDate, this.slot, this.cancelReason, required this.createdAt, this.history = const []});
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: _id(j['_id']),
        orderNo: j['orderNo'] ?? '',
        status: j['status'] ?? 'placed',
        paymentMethod: j['paymentMethod'] ?? 'COD',
        paymentStatus: j['paymentStatus'] ?? 'pending',
        items: (j['items'] as List? ?? []).map((e) => OrderItem.fromJson(e)).toList(),
        address: j['address'] == null ? null : Address.fromJson({...j['address'], '_id': ''}),
        itemsTotal: _d(j['itemsTotal']),
        mrpTotal: _d(j['mrpTotal']),
        savings: _d(j['savings']),
        couponDiscount: _d(j['couponDiscount']),
        deliveryFee: _d(j['deliveryFee']),
        handlingFee: _d(j['handlingFee']),
        grandTotal: _d(j['grandTotal']),
        couponCode: j['couponCode'],
        slotDate: j['deliverySlot']?['date'],
        slot: j['deliverySlot']?['slot'],
        cancelReason: j['cancelReason'],
        createdAt: DateTime.tryParse(j['createdAt'] ?? '')?.toLocal() ?? DateTime.now(),
        history: (j['statusHistory'] as List? ?? [])
            .map((h) => StatusEvent(h['status'] ?? '', h['note'], DateTime.tryParse(h['at'] ?? '')?.toLocal() ?? DateTime.now()))
            .toList(),
      );
  bool get canCancel => status == 'placed' || status == 'confirmed';
  int get itemCount => items.fold(0, (s, i) => s + i.qty);
}

class Coupon {
  final String code;
  final String? description;
  final String type;
  final double value, minOrder;
  Coupon({required this.code, this.description, required this.type, required this.value, required this.minOrder});
  factory Coupon.fromJson(Map<String, dynamic> j) =>
      Coupon(code: j['code'] ?? '', description: j['description'], type: j['type'] ?? 'flat', value: _d(j['value']), minOrder: _d(j['minOrder']));
}

class AppUser {
  final String id;
  final String? name, phone, email;
  AppUser({required this.id, this.name, this.phone, this.email});
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(id: _id(j['_id']), name: j['name'], phone: j['phone'], email: j['email']);
}

const orderStatusLabels = {
  'placed': 'Order Placed',
  'confirmed': 'Confirmed',
  'packed': 'Packed',
  'out_for_delivery': 'Out for Delivery',
  'delivered': 'Delivered',
  'cancelled': 'Cancelled',
};
