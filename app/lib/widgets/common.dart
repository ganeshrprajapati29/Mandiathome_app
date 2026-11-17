import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_screens.dart';
import '../theme/app_theme.dart';

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? Colors.redAccent.shade100 : AppColors.primaryLight, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
      duration: const Duration(seconds: 2),
    ));
}

/// Ensures the user is logged in; opens login if not. Returns true when logged in.
Future<bool> requireLogin(BuildContext context) async {
  if (context.read<AuthProvider>().isLoggedIn) return true;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen(popOnSuccess: true)));
  return ok == true;
}

/// Shows network image if present, otherwise a soft tile with the product emoji.
class ProductImage extends StatelessWidget {
  final String? url;
  final String? emoji;
  final double size;
  final double radius;
  final Color? bg;
  const ProductImage({super.key, this.url, this.emoji, this.size = 80, this.radius = 14, this.bg});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bg ?? const Color(0xFFF1F8E9), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(emoji ?? '🥬', style: TextStyle(fontSize: size * 0.52)),
    );
    final u = ApiConfig.image(url);
    if (u.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Shimmer.fromColors(baseColor: Colors.grey.shade200, highlightColor: Colors.white, child: Container(width: size, height: size, color: Colors.white)),
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  const SectionHeader({super.key, required this.title, this.subtitle, this.onSeeAll});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Row(children: [Text('See all', style: TextStyle(fontWeight: FontWeight.w600)), Icon(Icons.chevron_right, size: 18)]),
          ),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String emoji, title, message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.emoji, required this.title, required this.message, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(color: AppColors.soft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 56)),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            SizedBox(width: 200, child: ElevatedButton(onPressed: onAction, child: Text(actionLabel!))),
          ],
        ]),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => EmptyState(emoji: '📡', title: 'Oops!', message: message, actionLabel: 'Retry', onAction: onRetry);
}

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const ShimmerBox({super.key, this.width, required this.height, this.radius = 14});
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: const Color(0xFFEDEFEC),
        highlightColor: Colors.white,
        child: Container(width: width, height: height, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius))),
      );
}

class DiscountBadge extends StatelessWidget {
  final int percent;
  const DiscountBadge(this.percent, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
        child: Text('$percent% OFF', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
      );
}

class PriceText extends StatelessWidget {
  final double price, mrp;
  final double size;
  const PriceText({super.key, required this.price, required this.mrp, this.size = 15});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(rupee(price), style: TextStyle(fontSize: size, fontWeight: FontWeight.w700)),
        if (mrp > price) ...[
          const SizedBox(width: 5),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(rupee(mrp), style: TextStyle(fontSize: size - 3, color: AppColors.textMuted, decoration: TextDecoration.lineThrough)),
          ),
        ],
      ]);
}

/// Category / sub-category artwork: photo icon (transparent PNG) on the category colour, or emoji fallback.
class CategoryThumb extends StatelessWidget {
  final String? image, emoji, color;
  final double size;
  final bool circle;
  const CategoryThumb({super.key, this.image, this.emoji, this.color, required this.size, this.circle = false});
  @override
  Widget build(BuildContext context) {
    final r = circle ? size / 2 : size * .22;
    final hasImg = (image ?? '').isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.fromHex(color), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(r),
        border: circle ? null : Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: hasImg
          ? Padding(
              padding: EdgeInsets.all(size * .06),
              child: CachedNetworkImage(
                imageUrl: ApiConfig.image(image),
                fit: BoxFit.contain,
                placeholder: (_, __) => Text(emoji ?? '🥬', style: TextStyle(fontSize: size * .45)),
                errorWidget: (_, __, ___) => Text(emoji ?? '🥬', style: TextStyle(fontSize: size * .45)),
              ),
            )
          : Text(emoji ?? '🥬', style: TextStyle(fontSize: size * .45)),
    );
  }
}
