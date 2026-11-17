import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';

/// Full-screen OpenStreetMap picker: drag the map under the centre pin, search a place,
/// or jump to current GPS location. Pops with a [PlaceInfo].
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late LatLng _center = widget.initial ?? defaultCenter;
  PlaceInfo? _place;
  bool _resolving = false, _moving = false, _locating = false;
  Timer? _debounce, _searchDebounce;
  final _searchCtrl = TextEditingController();
  List<PlaceInfo> _results = [];
  bool _searching = false;
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: 1);

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToMyLocation(silent: true));
    } else {
      _resolve();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();
    _bounce.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation({bool silent = false}) async {
    setState(() => _locating = true);
    try {
      final p = await LocationService.current();
      _center = p;
      _map.move(p, 17);
      _resolve();
    } catch (e) {
      if (!silent && mounted) showSnack(context, e.toString(), error: true);
      if (silent) _resolve();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _resolve() {
    _debounce?.cancel();
    setState(() => _resolving = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final at = _center;
      final p = await LocationService.reverse(at);
      if (!mounted || at != _center) return;
      setState(() {
        _place = p ?? PlaceInfo(point: at, title: 'Pinned location', display: '${at.latitude.toStringAsFixed(5)}, ${at.longitude.toStringAsFixed(5)}');
        _resolving = false;
      });
    });
  }

  void _onSearch(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (q.trim().length < 3) return setState(() => _results = []);
      setState(() => _searching = true);
      final r = await LocationService.search(q);
      if (mounted) {
        setState(() {
          _results = r;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: widget.initial == null ? 5 : 17,
            minZoom: 4,
            maxZoom: 19,
            onPositionChanged: (pos, hasGesture) {
              _center = pos.center;
              if (hasGesture && !_moving) setState(() => _moving = true);
            },
            onMapEvent: (e) {
              if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd || e is MapEventScrollWheelZoom) {
                if (_moving) {
                  setState(() => _moving = false);
                  _bounce.forward(from: 0);
                }
                _resolve();
              }
            },
          ),
          children: osmLayers(),
        ),
        // centre pin
        IgnorePointer(
          child: Center(
            child: AnimatedBuilder(
              animation: _bounce,
              builder: (_, child) {
                final lift = _moving ? -16.0 : -(1 - Curves.bounceOut.transform(_bounce.value)) * 16;
                return Transform.translate(offset: Offset(0, -24 + lift), child: child);
              },
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedOpacity(
                  opacity: _moving ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(10)),
                    child: const Text('Your order will be delivered here', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ),
                const MapPin(size: 50),
              ]),
            ),
          ),
        ),
        Center(
          child: IgnorePointer(
            child: Container(width: 10, height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10))),
          ),
        ),
        // search bar
        Positioned(
          top: top + 10,
          left: 12,
          right: 12,
          child: Column(children: [
            Row(children: [
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search area, street, landmark…',
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searching
                          ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                          : (_searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _results = []);
                                  })),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
            ]),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8, left: 56),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)]),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(r.display, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _center = r.point;
                        _map.move(r.point, 17);
                        setState(() => _results = []);
                        _resolve();
                      },
                    );
                  },
                ),
              ),
          ]),
        ),
        // my location button
        Positioned(
          right: 16,
          bottom: 230 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.small(
            heroTag: 'myloc',
            backgroundColor: Colors.white,
            onPressed: _locating ? null : () => _goToMyLocation(),
            child: _locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, color: AppColors.primary),
          ),
        ),
        // bottom card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SELECT DELIVERY LOCATION', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.location_on, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, if (cur != null) cur]),
                    child: (_resolving || _place == null)
                        ? const Column(key: ValueKey('l'), crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ShimmerBox(height: 16, width: 140, radius: 6),
                            SizedBox(height: 8),
                            ShimmerBox(height: 12, radius: 6),
                          ])
                        : Column(key: ValueKey(_place!.display), crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_place!.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(_place!.display,
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                          ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (_resolving || _place == null) ? null : () => Navigator.pop(context, _place),
                child: const Text('Confirm Location'),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
