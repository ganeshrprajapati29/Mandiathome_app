import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Address details resolved from OpenStreetMap (Nominatim).
class PlaceInfo {
  final LatLng point;
  final String title; // short name, e.g. "Vijay Nagar"
  final String display; // full readable address
  final String line; // house/road/area line
  final String city, state, pincode;
  PlaceInfo({required this.point, required this.title, required this.display, this.line = '', this.city = '', this.state = '', this.pincode = ''});

  factory PlaceInfo.fromNominatim(Map<String, dynamic> j) {
    final a = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};
    String pick(List<String> keys) => keys.map((k) => a[k]?.toString() ?? '').firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final area = pick(['neighbourhood', 'suburb', 'quarter', 'residential', 'hamlet', 'village']);
    final road = pick(['road', 'pedestrian', 'street']);
    final house = pick(['house_number', 'building', 'amenity', 'shop']);
    final city = pick(['city', 'town', 'city_district', 'municipality', 'village', 'county', 'state_district']);
    final line = [house, road, area].where((e) => e.isNotEmpty).toSet().join(', ');
    return PlaceInfo(
      point: LatLng(double.tryParse('${j['lat']}') ?? 0, double.tryParse('${j['lon']}') ?? 0),
      title: area.isNotEmpty ? area : (road.isNotEmpty ? road : (city.isNotEmpty ? city : (j['name'] ?? 'Selected location'))),
      display: j['display_name'] ?? '',
      line: line,
      city: city,
      state: a['state']?.toString() ?? '',
      pincode: (a['postcode']?.toString() ?? '').replaceAll(' ', ''),
    );
  }
}

class LocationService {
  static const _base = 'https://nominatim.openstreetmap.org';
  static const userAgent = 'MandiAtHome/1.0 (com.mandiathome.app)';
  static Map<String, String> get _headers => kIsWeb ? {'Accept-Language': 'en'} : {'User-Agent': userAgent, 'Accept-Language': 'en'};

  /// Default map centre (India) when we don't know the user's location yet.
  static final LatLng fallback = LatLng(22.7196, 75.8577);

  /// Returns the device location, asking for permission. Throws a friendly message on failure.
  static Future<LatLng> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location is turned off. Please enable GPS.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) throw 'Location permission denied';
    if (perm == LocationPermission.deniedForever) {
      throw 'Location permission is blocked. Enable it from app settings.';
    }
    final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
    return LatLng(p.latitude, p.longitude);
  }

  static Future<PlaceInfo?> reverse(LatLng p) async {
    try {
      final r = await http
          .get(Uri.parse('$_base/reverse?format=jsonv2&addressdetails=1&zoom=18&lat=${p.latitude}&lon=${p.longitude}'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map<String, dynamic> || j['error'] != null) return null;
      final info = PlaceInfo.fromNominatim(j);
      return PlaceInfo(point: p, title: info.title, display: info.display, line: info.line, city: info.city, state: info.state, pincode: info.pincode);
    } catch (_) {
      return null;
    }
  }

  static Future<List<PlaceInfo>> search(String q) async {
    if (q.trim().length < 3) return [];
    try {
      final r = await http
          .get(Uri.parse('$_base/search?format=jsonv2&addressdetails=1&limit=6&countrycodes=in&q=${Uri.encodeQueryComponent(q.trim())}'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return [];
      return (jsonDecode(utf8.decode(r.bodyBytes)) as List).map((e) => PlaceInfo.fromNominatim(e)).toList();
    } catch (_) {
      return [];
    }
  }
}
