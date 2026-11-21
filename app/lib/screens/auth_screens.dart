import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'address_screens.dart';
import 'main_shell.dart';

/// Phone login. With [gate] = true it is the app's entry screen (no close button)
/// and continues to the home screen after login.
class LoginScreen extends StatefulWidget {
  final bool gate;
  final bool popOnSuccess;
  const LoginScreen({super.key, this.gate = false, this.popOnSuccess = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  bool _loading = false;
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid => RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text.trim());

  Future<void> _send() async {
    final p = _phone.text.trim();
    if (!_valid) return showSnack(context, 'Enter a valid 10-digit mobile number', error: true);
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final r = await context.read<AuthProvider>().sendOtp(p);
      if (!mounted) return;
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: p, devOtp: r.devOtp, length: r.length)));
      if (ok != true || !mounted) return;
      if (widget.gate) {
        // First-time users: ask for delivery location right away.
        if (context.read<AuthProvider>().addresses.isEmpty) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressFormScreen()));
          if (!mounted) return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => const MainShell(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
          (_) => false,
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return PopScope(
      canPop: !widget.gate,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: top + 8, bottom: 28),
              decoration: const BoxDecoration(color: AppColors.splashBg, borderRadius: BorderRadius.vertical(bottom: Radius.circular(40))),
              child: Stack(children: [
                // floating veggies
                ...[('🥕', .06, .25), ('🍅', .82, .12), ('🥦', .88, .62), ('🍎', .04, .72), ('🍌', .5, .02)].map((e) => AnimatedBuilder(
                      animation: _float,
                      builder: (_, __) => Positioned.fill(
                        child: Align(
                          alignment: Alignment(e.$2 * 2 - 1, e.$3 * 2 - 1 + (_float.value - .5) * .08 * (e.$2 > .5 ? 1 : -1)),
                          child: Opacity(opacity: .55, child: Text(e.$1, style: const TextStyle(fontSize: 28))),
                        ),
                      ),
                    )),
                SizedBox(
                  width: double.infinity,
                  child: Column(children: [
                    SizedBox(
                      height: 48,
                      child: widget.gate
                          ? null
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false))),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: .8, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) => Transform.scale(scale: v, child: child),
                      child: Image.asset('assets/images/logo_wide.png', width: 260),
                    ),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('India ka apna mandi, ab ghar pe 🧺', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('Login or Sign up', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Enter your mobile number to get an OTP', style: TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _valid ? AppColors.primary : AppColors.border, width: _valid ? 1.6 : 1),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(_valid ? .12 : 0), blurRadius: 14, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: const BoxDecoration(border: Border(right: BorderSide(color: AppColors.border))),
                      child: const Text('🇮🇳 +91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 2),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'Mobile number',
                          hintStyle: TextStyle(letterSpacing: 0, fontWeight: FontWeight.w400, fontSize: 16, color: AppColors.textMuted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _valid ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.check_circle, color: AppColors.primary)),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _valid ? 1 : .55,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _send,
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center, children: [Text('Get OTP'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)]),
                  ),
                ),
                const SizedBox(height: 28),
                Row(children: [
                  _perk('🚚', 'Fast delivery'),
                  _perk('🌾', 'Mandi fresh'),
                  _perk('💵', 'Cash on delivery'),
                ]),
                const SizedBox(height: 22),
                const Center(
                  child: Text('By continuing you agree to our Terms of Service & Privacy Policy',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _perk(String e, String t) => Expanded(
        child: Column(children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: AppColors.soft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(e, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 6),
          Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
        ]),
      );
}

class OtpScreen extends StatefulWidget {
  final String phone;
  final String? devOtp;
  final int length;
  const OtpScreen({super.key, required this.phone, this.devOtp, this.length = 6});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  late final int _n = widget.length;
  late final _ctrls = List.generate(_n, (_) => TextEditingController());
  late final _nodes = List.generate(_n, (_) => FocusNode());
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  bool _loading = false;
  int _seconds = 30;
  Timer? _timer, _autoFill;
  late String? _otpShown = widget.devOtp;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _scheduleAutoFill();
  }

  /// Simulates SMS auto-read: fills the OTP shown on screen after a moment.
  void _scheduleAutoFill() {
    _autoFill?.cancel();
    if (_otpShown == null) return;
    _autoFill = Timer(const Duration(milliseconds: 1600), () => _fill(_otpShown!));
  }

  Future<void> _fill(String code) async {
    for (var i = 0; i < _n && i < code.length; i++) {
      if (!mounted) return;
      _ctrls[i].text = code[i];
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 120));
    }
    _verify();
  }

  void _startTimer() {
    _seconds = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds == 0) {
        t.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoFill?.cancel();
    _shake.dispose();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != _n || _loading) return;
    _autoFill?.cancel();
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final needsName = await auth.verifyOtp(widget.phone, _otp);
      if (!mounted) return;
      await Future.wait([context.read<CartProvider>().load(), context.read<StoreProvider>().loadWishlist()]);
      if (!mounted) return;
      if (needsName) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _shake.forward(from: 0);
      for (final c in _ctrls) {
        c.clear();
      }
      _nodes[0].requestFocus();
      showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    for (final c in _ctrls) {
      c.clear();
    }
    try {
      final r = await context.read<AuthProvider>().sendOtp(widget.phone);
      _startTimer();
      setState(() => _otpShown = r.devOtp);
      _scheduleAutoFill();
      if (mounted) showSnack(context, r.devOtp == null ? 'New OTP sent by SMS' : 'New OTP sent');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
        // OTP "notification" card shown on screen (until SMS gateway is connected)
        if (_otpShown != null)
          TweenAnimationBuilder<double>(
            key: ValueKey(_otpShown),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.translate(offset: Offset(0, (1 - v) * -40), child: child)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.greenGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(.3), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.sms_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Mandi At Home • now', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: [
                      const TextSpan(text: 'Your OTP is  ', style: TextStyle(color: Colors.white, fontSize: 14)),
                      TextSpan(text: _otpShown, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 4)),
                    ])),
                  ]),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: () => _fill(_otpShown!),
                  child: const Text('Auto-fill', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        const Text('Verify OTP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(text: 'Enter the $_n-digit code sent by SMS to ', style: const TextStyle(color: AppColors.textMuted)),
          TextSpan(text: '+91 ${widget.phone}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ])),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          onPressed: () => Navigator.pop(context),
          child: const Text('Change number'),
        ),
        const SizedBox(height: 16),
        AnimatedBuilder(
          animation: _shake,
          builder: (_, child) => Transform.translate(offset: Offset(sin(_shake.value * pi * 6) * 10 * (1 - _shake.value), 0), child: child),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_n, (i) {
              final filled = _ctrls[i].text.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _n > 4 ? 48 : 64,
                height: _n > 4 ? 58 : 68,
                decoration: BoxDecoration(
                  color: filled ? AppColors.soft : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: filled ? AppColors.primary : AppColors.border, width: filled ? 1.8 : 1),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _ctrls[i],
                  focusNode: _nodes[i],
                  autofocus: i == 0,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    setState(() {});
                    if (v.isNotEmpty && i < _n - 1) _nodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
                    if (_otp.length == _n) _verify();
                  },
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _loading ? null : _verify,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Verify & Continue'),
        ),
        const SizedBox(height: 16),
        Center(
          child: _seconds > 0
              ? Text("Didn't get it? Resend in 00:${_seconds.toString().padLeft(2, '0')}", style: const TextStyle(color: AppColors.textMuted))
              : TextButton.icon(onPressed: _resend, icon: const Icon(Icons.refresh), label: const Text('Resend OTP')),
        ),
      ]),
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _name = TextEditingController(text: context.read<AuthProvider>().user?.name ?? '');
  late final _email = TextEditingController(text: context.read<AuthProvider>().user?.email ?? '');
  bool _loading = false;

  Future<void> _save() async {
    if (_name.text.trim().length < 2) return showSnack(context, 'Please enter your name', error: true);
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().updateProfile(name: _name.text.trim(), email: _email.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Your profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Center(child: Text('👋', style: TextStyle(fontSize: 64))),
          const SizedBox(height: 12),
          const Center(child: Text('Tell us a little about you', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          const SizedBox(height: 28),
          TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Full name *', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline))),
          const Spacer(),
          ElevatedButton(onPressed: _loading ? null : _save, child: const Text('Save & Continue')),
        ]),
      ),
    );
  }
}
