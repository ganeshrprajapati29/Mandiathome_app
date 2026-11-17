import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/store_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  /// When true, pops with `true` after successful login (used by requireLogin()).
  final bool popOnSuccess;
  const LoginScreen({super.key, this.popOnSuccess = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  bool _loading = false;

  Future<void> _send() async {
    final p = _phone.text.trim();
    if (p.length != 10) return showSnack(context, 'Enter a valid 10-digit mobile number', error: true);
    setState(() => _loading = true);
    try {
      final dev = await context.read<AuthProvider>().sendOtp(p);
      if (!mounted) return;
      final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => OtpScreen(phone: p, devOtp: dev)));
      if (ok == true && mounted) Navigator.pop(context, true);
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
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 30),
            decoration: const BoxDecoration(
              color: AppColors.splashBg,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, false)),
              ),
              Hero(tag: 'logo', child: Image.asset('assets/images/logo.png', width: 210)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Login or Sign up', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Enter your mobile number, we will send you an OTP', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.5),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '98765 43210',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(left: 16, right: 8),
                    child: Text('🇮🇳  +91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _send,
                child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Get OTP'),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('By continuing you agree to our Terms of Service & Privacy Policy',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class OtpScreen extends StatefulWidget {
  final String phone;
  final String? devOtp;
  const OtpScreen({super.key, required this.phone, this.devOtp});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _ctrls = List.generate(4, (_) => TextEditingController());
  final _nodes = List.generate(4, (_) => FocusNode());
  bool _loading = false;
  int _seconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (widget.devOtp != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showSnack(context, 'Test OTP: ${widget.devOtp}'));
    }
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
    if (_otp.length != 4) return;
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
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      final dev = await context.read<AuthProvider>().sendOtp(widget.phone);
      _startTimer();
      if (mounted) showSnack(context, dev != null ? 'OTP resent. Test OTP: $dev' : 'OTP resent');
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Verify OTP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Enter the 4-digit code sent to ', style: TextStyle(color: AppColors.textMuted)),
            TextSpan(text: '+91 ${widget.phone}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (i) {
              return SizedBox(
                width: 64,
                child: TextField(
                  controller: _ctrls[i],
                  focusNode: _nodes[i],
                  autofocus: i == 0,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(counterText: '', contentPadding: EdgeInsets.symmetric(vertical: 16)),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 3) _nodes[i + 1].requestFocus();
                    if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
                    if (_otp.length == 4) _verify();
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _loading ? null : _verify,
            child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Verify & Continue'),
          ),
          const SizedBox(height: 16),
          Center(
            child: _seconds > 0
                ? Text('Resend OTP in 00:${_seconds.toString().padLeft(2, '0')}', style: const TextStyle(color: AppColors.textMuted))
                : TextButton(onPressed: _resend, child: const Text('Resend OTP')),
          ),
        ]),
      ),
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
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Full name *', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 14),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline))),
          const Spacer(),
          ElevatedButton(onPressed: _loading ? null : _save, child: const Text('Save & Continue')),
        ]),
      ),
    );
  }
}
