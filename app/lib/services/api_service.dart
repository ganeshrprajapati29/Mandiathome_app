import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

/// Thin HTTP client: JSON in/out, bearer token, friendly error messages.
class Api {
  Api._();
  static final Api instance = Api._();

  String? _token;
  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// Called when the server says the session is invalid.
  void Function()? onUnauthorized;

  Future<void> loadToken() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('token');
  }

  Future<void> setToken(String? t) async {
    _token = t;
    final sp = await SharedPreferences.getInstance();
    if (t == null) {
      await sp.remove('token');
    } else {
      await sp.setString('token', t);
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path) => _send(() => http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers));
  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => http.post(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => http.put(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers, body: jsonEncode(body ?? {})));
  Future<dynamic> delete(String path) => _send(() => http.delete(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() fn) async {
    http.Response res;
    try {
      res = await fn().timeout(const Duration(seconds: 20));
    } on SocketException {
      throw ApiException('No internet connection. Please check your network.');
    } on TimeoutException {
      throw ApiException('Server is taking too long. Please try again.');
    } catch (_) {
      throw ApiException('Could not connect to server.');
    }
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && hasToken) onUnauthorized?.call();
    throw ApiException((data is Map ? data['message'] : null) ?? 'Something went wrong (${res.statusCode})', res.statusCode);
  }
}
