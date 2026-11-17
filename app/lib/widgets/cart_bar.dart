import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Floating "View cart" bar that slides up whenever the cart has items.
class CartBar extends StatelessWidget {
  const CartBar({super.key});
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final s = cart.summary;
    final show = s.items.isNotEmpty;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      offset: show ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: show ? 1 : 0,
        child: !show
            ? const SizedBox.shrink()
            : GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.greenGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(.35), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 64,
                      height: 36,
                      child: Stack(children: [
                        for (var i = 0; i < s.items.length && i < 3; i++)
                          Positioned(
                            left: i * 14.0,
                            child: Container(
                              decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(10)),
                              child: ProductImage(url: s.items[i].image, emoji: s.items[i].emoji, size: 32, radius: 8, bg: Colors.white),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('${s.count} item${s.count > 1 ? 's' : ''}  •  ${rupee(s.itemsTotal)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(
                          s.amountForFreeDelivery > 0 ? 'Add ${rupee(s.amountForFreeDelivery)} more for FREE delivery' : '🎉 You got FREE delivery',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ]),
                    ),
                    const Text('View Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ]),
                ),
              ),
      ),
    );
  }
}
