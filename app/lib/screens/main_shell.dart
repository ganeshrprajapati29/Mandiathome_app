import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'auth_screens.dart';
import 'cart_screen.dart';
import 'categories_screen.dart';
import 'home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  static final tab = ValueNotifier<int>(0);
  static void switchTab(BuildContext context, int i) => tab.value = i;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool _redirecting = false;
  int get _tab => MainShell.tab.value;
  void setTab(int i) => MainShell.tab.value = i;
  void _onTab() => setState(() {});

  @override
  void initState() {
    super.initState();
    MainShell.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    MainShell.tab.removeListener(_onTab);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = context.select<CartProvider, int>((c) => c.count);
    // Session expired / logged out elsewhere -> back to login.
    final loggedOut = context.select<AuthProvider, bool>((a) => a.ready && !a.isLoggedIn);
    if (loggedOut && !_redirecting) {
      _redirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        MainShell.tab.value = 0;
        context.read<CartProvider>().reset();
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen(gate: true)), (_) => false);
      });
    }
    return PopScope(
      canPop: _tab == 0,
      onPopInvoked: (didPop) {
        if (!didPop) setTab(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _tab, children: const [HomeScreen(), CategoriesScreen(), CartScreen(embedded: true), AccountScreen()]),
        bottomNavigationBar: Container(
          decoration:
              BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, -4))]),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(children: [
                _NavItem(icon: Icons.storefront_outlined, active: Icons.storefront, label: 'Home', selected: _tab == 0, onTap: () => setTab(0)),
                _NavItem(icon: Icons.grid_view_outlined, active: Icons.grid_view_rounded, label: 'Categories', selected: _tab == 1, onTap: () => setTab(1)),
                _NavItem(
                    icon: Icons.shopping_bag_outlined, active: Icons.shopping_bag, label: 'Cart', selected: _tab == 2, badge: count, onTap: () => setTab(2)),
                _NavItem(icon: Icons.person_outline, active: Icons.person, label: 'Account', selected: _tab == 3, onTap: () => setTab(3)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, active;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.active, required this.label, required this.selected, required this.onTap, this.badge = 0});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: selected ? AppColors.soft : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AppColors.accent,
              child: AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 250),
                child: Icon(selected ? active : icon, color: selected ? AppColors.primary : AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.primary : AppColors.textMuted)),
          ]),
        ),
      ),
    );
  }
}
