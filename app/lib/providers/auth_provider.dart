import 'package:flutter/foundation.dart' show ChangeNotifier;
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _api = Api.instance;
  AppUser? user;
  List<Address> addresses = [];
  bool ready = false;

  bool get isLoggedIn => user != null;

  Future<void> init() async {
    await _api.loadToken();
    _api.onUnauthorized = () => logout();
    if (_api.hasToken) {
      try {
        final r = await _api.get('/auth/me');
        _setUser(r['user']);
      } catch (e) {
        if (e is ApiException && e.status == 401) await _api.setToken(null);
      }
    }
    ready = true;
    notifyListeners();
  }

  void _setUser(Map<String, dynamic> j) {
    user = AppUser.fromJson(j);
    addresses = (j['addresses'] as List? ?? []).map((e) => Address.fromJson(e)).toList();
  }

  /// Returns dev OTP when backend is in OTP_DEV_MODE (for testing).
  /// Sends an OTP. Returns the OTP length and, only in test mode, the OTP itself.
  Future<({String? devOtp, int length})> sendOtp(String phone) async {
    final r = await _api.post('/auth/send-otp', {'phone': phone});
    final len = r['otpLength'];
    return (devOtp: r['devOtp']?.toString(), length: len is num ? len.toInt() : 6);
  }

  /// Returns true if the user still needs to set their name.
  Future<bool> verifyOtp(String phone, String otp) async {
    final r = await _api.post('/auth/verify-otp', {'phone': phone, 'otp': otp});
    await _api.setToken(r['token']);
    _setUser(r['user']);
    notifyListeners();
    return (user?.name ?? '').isEmpty;
  }

  Future<void> updateProfile({String? name, String? email}) async {
    final r = await _api.put('/auth/me', {if (name != null) 'name': name, if (email != null) 'email': email});
    _setUser(r['user']);
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.setToken(null);
    user = null;
    addresses = [];
    notifyListeners();
  }

  // ---------- addresses ----------
  Address? get defaultAddress => addresses.isEmpty ? null : addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);

  void _setAddresses(dynamic list) {
    addresses = (list as List).map((e) => Address.fromJson(e)).toList();
    notifyListeners();
  }

  Future<void> addAddress(Address a) async => _setAddresses((await _api.post('/user/addresses', a.toJson()))['data']);
  Future<void> updateAddress(String id, Address a) async => _setAddresses((await _api.put('/user/addresses/$id', a.toJson()))['data']);
  Future<void> deleteAddress(String id) async => _setAddresses((await _api.delete('/user/addresses/$id'))['data']);
  Future<void> setDefaultAddress(String id) async => _setAddresses((await _api.put('/user/addresses/$id', {'isDefault': true}))['data']);
}
