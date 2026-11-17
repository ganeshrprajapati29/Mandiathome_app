import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

/// OpenStreetMap tile layer (with required attribution).
List<Widget> osmLayers() => [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.mandiathome.app',
        maxZoom: 19,
      ),
      const Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: DecoratedBox(
            decoration: BoxDecoration(color: Color(0xCCFFFFFF)),
            child:
                Padding(padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1), child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 9))),
          ),
        ),
      ),
    ];

/// Small non-interactive map with a pin — used in address form & order details.
class MapPreview extends StatelessWidget {
  final double lat, lng;
  final double height;
  const MapPreview({super.key, required this.lat, required this.lng, this.height = 140});
  @override
  Widget build(BuildContext context) {
    final p = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(initialCenter: p, initialZoom: 16, interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)),
          children: [
            ...osmLayers().take(1),
            MarkerLayer(markers: [Marker(point: p, width: 44, height: 44, alignment: Alignment.topCenter, child: const MapPin(size: 40))]),
            ...osmLayers().skip(1),
          ],
        ),
      ),
    );
  }
}

class MapPin extends StatelessWidget {
  final double size;
  const MapPin({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.location_on, size: size, color: AppColors.accent, shadows: const [Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))]);
}

LatLng get defaultCenter => LocationService.fallback;
