import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/product_widgets.dart';
import 'address_screens.dart';
import 'auth_screens.dart';
import 'order_screens.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<StoreProvider>().settings;
    final u = auth.user;

    Widget tile(IconData i, String t, VoidCallback onTap, {String? sub, Color? color}) => ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (color ?? AppColors.primary).withOpacity(.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(i, color: color ?? AppColors.primary, size: 20),
          ),
          title: Text(t, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          subtitle: sub != null ? Text(sub, style: const TextStyle(fontSize: 12)) : null,
          trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        );

    Future<void> needLogin(Widget page) async {
      if (await requireLogin(context) && context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 28),
          decoration: const BoxDecoration(gradient: AppColors.greenGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
          child: Row(children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              child: Text(
                u == null ? '👤' : ((u.name ?? '').isNotEmpty ? u.name![0].toUpperCase() : '😊'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: u == null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Welcome!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      const Text('Login to track orders & save addresses', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, minimumSize: const Size(110, 36)),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                          child: const Text('Login'),
                        ),
                      ),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((u.name ?? '').isEmpty ? 'Hello!' : u.name!, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('+91 ${u.phone ?? ''}', style: const TextStyle(color: Colors.white70)),
                      if ((u.email ?? '').isNotEmpty) Text(u.email!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
            ),
            if (u != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen())),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        _group([
          tile(Icons.receipt_long_outlined, 'My Orders', () => needLogin(const OrdersScreen()), sub: 'Track, cancel & view past orders'),
          tile(Icons.favorite_border, 'Wishlist', () => needLogin(const WishlistScreen()), sub: 'Your saved favourites'),
          tile(Icons.location_on_outlined, 'Saved Addresses', () => needLogin(const AddressListScreen())),
        ]),
        _group([
          tile(Icons.support_agent, 'Help & Support', () => _support(context, settings), sub: settings.supportPhone),
          tile(Icons.info_outline, 'About Mandi At Home', () => _about(context)),
        ]),
        if (u != null)
          _group([
            tile(Icons.logout, 'Logout', () async {
              await auth.logout();
              if (!context.mounted) return;
              context.read<CartProvider>().reset();
              context.read<StoreProvider>().loadWishlist();
              // MainShell notices the logout and returns to the login screen.
            }, color: AppColors.danger),
          ]),
        const SizedBox(height: 20),
        Center(child: Image.asset('assets/images/logo_wide.png', width: 130)),
        const Center(child: Text('Version 1.0.0', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _group(List<Widget> children) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      );

  void _support(BuildContext context, StoreSettings s) => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🤝', style: TextStyle(fontSize: 48)),
              const Text('We are here to help', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(leading: const Icon(Icons.phone, color: AppColors.primary), title: Text(s.supportPhone.isEmpty ? '-' : s.supportPhone)),
              ListTile(leading: const Icon(Icons.email_outlined, color: AppColors.primary), title: Text(s.supportEmail.isEmpty ? '-' : s.supportEmail)),
              const ListTile(leading: Icon(Icons.schedule, color: AppColors.primary), title: Text('7 AM – 9 PM, all days')),
            ]),
          ),
        ),
      );

  void _about(BuildContext context) => showAboutDialog(
        context: context,
        applicationName: 'Mandi At Home',
        applicationVersion: '1.0.0',
        applicationIcon: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/images/logo.png', width: 56)),
        children: const [Text('Fresh fruits & vegetables from the mandi, delivered to your doorstep at mandi prices.')],
      );
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});
  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Product>? _items;
  @override
  void initState() {
    super.initState();
    context.read<StoreProvider>().wishlistProducts().then((v) {
      if (mounted) setState(() => _items = v);
    }).catchError((e) {
      if (mounted) setState(() => _items = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<StoreProvider>().wishlist;
    final items = _items?.where((p) => ids.contains(p.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const EmptyState(emoji: '💚', title: 'No favourites yet', message: 'Tap the heart on any product to save it here.')
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: productGridDelegate,
                  itemCount: items.length,
                  itemBuilder: (_, i) => ProductCard(product: items[i]),
                ),
    );
  }
}
