import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';
import '../widgets/common.dart';
import '../widgets/osm_map.dart';
import 'map_picker_screen.dart';

class AddressListScreen extends StatelessWidget {
  /// When true, tapping an address pops with its id.
  final bool selectMode;
  const AddressListScreen({super.key, this.selectMode = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final list = auth.addresses;
    return Scaffold(
      appBar: AppBar(title: Text(selectMode ? 'Select address' : 'My addresses')),
      body: list.isEmpty
          ? EmptyState(
              emoji: '📍',
              title: 'No saved addresses',
              message: 'Add an address so we know where to deliver your fresh basket.',
              actionLabel: 'Add Address',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressFormScreen())),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final a = list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: selectMode ? () => Navigator.pop(context, a.id) : null,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: a.isDefault ? AppColors.primary : AppColors.border, width: a.isDefault ? 1.5 : 1),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
                        child: Icon(
                            a.label == 'Home'
                                ? Icons.home_outlined
                                : a.label == 'Work'
                                    ? Icons.work_outline
                                    : Icons.location_on_outlined,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (a.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                                child: const Text('DEFAULT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 4),
                          Text('${a.name} • ${a.phone}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(a.full, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
                        ]),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          try {
                            if (v == 'edit') {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => AddressFormScreen(address: a)));
                            } else if (v == 'default') {
                              await auth.setDefaultAddress(a.id);
                            } else if (v == 'delete') {
                              await auth.deleteAddress(a.id);
                            }
                          } catch (e) {
                            if (context.mounted) showSnack(context, e.toString(), error: true);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          if (!a.isDefault) const PopupMenuItem(value: 'default', child: Text('Set as default')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
      floatingActionButton: list.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressFormScreen())),
              icon: const Icon(Icons.add),
              label: const Text('Add new'),
            ),
    );
  }
}

class AddressFormScreen extends StatefulWidget {
  final Address? address;

  /// Opens the map picker automatically (used for new addresses / first-time setup).
  final bool openMapFirst;
  const AddressFormScreen({super.key, this.address, this.openMapFirst = true});
  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  late String _label = widget.address?.label ?? 'Home';
  late final _name = TextEditingController(text: widget.address?.name ?? context.read<AuthProvider>().user?.name ?? '');
  late final _phone = TextEditingController(text: widget.address?.phone ?? context.read<AuthProvider>().user?.phone ?? '');
  late final _line1 = TextEditingController(text: widget.address?.line1);
  late final _line2 = TextEditingController(text: widget.address?.line2);
  late final _landmark = TextEditingController(text: widget.address?.landmark);
  late final _city = TextEditingController(text: widget.address?.city);
  late final _state = TextEditingController(text: widget.address?.state);
  late final _pincode = TextEditingController(text: widget.address?.pincode);
  late bool _default = widget.address?.isDefault ?? context.read<AuthProvider>().addresses.isEmpty;
  late double? _lat = widget.address?.lat;
  late double? _lng = widget.address?.lng;
  String? _placeTitle;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.address == null && widget.openMapFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickOnMap());
    }
  }

  Future<void> _pickOnMap() async {
    final place = await Navigator.push<PlaceInfo>(
      context,
      MaterialPageRoute(builder: (_) => MapPickerScreen(initial: _lat != null && _lng != null ? LatLng(_lat!, _lng!) : null)),
    );
    if (place == null || !mounted) return;
    setState(() {
      _lat = place.point.latitude;
      _lng = place.point.longitude;
      _placeTitle = place.title;
      if (place.line.isNotEmpty) _line2.text = place.line;
      if (place.city.isNotEmpty) _city.text = place.city;
      if (place.state.isNotEmpty) _state.text = place.state;
      if (place.pincode.isNotEmpty) _pincode.text = place.pincode;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final a = Address(
      id: widget.address?.id ?? '',
      label: _label,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim(),
      landmark: _landmark.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
      lat: _lat,
      lng: _lng,
      isDefault: _default,
    );
    try {
      final auth = context.read<AuthProvider>();
      widget.address == null ? await auth.addAddress(a) : await auth.updateAddress(widget.address!.id, a);
      if (!mounted) return;
      showSnack(context, 'Address saved 📍');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label, {String? Function(String?)? validator, TextInputType? type, int? max, IconData? icon}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            validator: validator,
            keyboardType: type,
            maxLength: max,
            inputFormatters: type == TextInputType.number || type == TextInputType.phone ? [FilteringTextInputFormatter.digitsOnly] : null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: label, counterText: '', prefixIcon: icon != null ? Icon(icon, size: 20) : null),
          ),
        );
    final hasLoc = _lat != null && _lng != null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.address == null ? 'Add delivery address' : 'Edit address')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // map card
          GestureDetector(
            onTap: _pickOnMap,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: Column(children: [
                if (hasLoc)
                  Stack(children: [
                    MapPreview(lat: _lat!, lng: _lng!, height: 150),
                    Positioned.fill(child: Container(color: Colors.transparent)),
                  ])
                else
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      gradient: const LinearGradient(colors: [AppColors.soft, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                    alignment: Alignment.center,
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('🗺️', style: TextStyle(fontSize: 44)),
                      SizedBox(height: 6),
                      Text('Pin your exact location on the map', style: TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasLoc ? (_placeTitle ?? 'Location pinned on map') : 'No location selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton.icon(onPressed: _pickOnMap, icon: const Icon(Icons.map_outlined, size: 18), label: Text(hasLoc ? 'Change' : 'Open map')),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Save address as', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [('Home', Icons.home_outlined), ('Work', Icons.work_outline), ('Other', Icons.location_on_outlined)]
                .map((l) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(l.$2, size: 16, color: _label == l.$1 ? AppColors.primary : AppColors.textMuted),
                        label: Text(l.$1),
                        selected: _label == l.$1,
                        onSelected: (_) => setState(() => _label = l.$1),
                        selectedColor: AppColors.soft,
                        showCheckmark: false,
                        side: BorderSide(color: _label == l.$1 ? AppColors.primary : AppColors.border),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          field(_line1, 'House / Flat no., Floor, Building *', validator: _req, icon: Icons.home_outlined),
          field(_line2, 'Street, Area, Colony', icon: Icons.signpost_outlined),
          field(_landmark, 'Landmark (optional)', icon: Icons.flag_outlined),
          Row(children: [
            Expanded(child: field(_city, 'City *', validator: _req)),
            const SizedBox(width: 12),
            Expanded(
                child: field(_pincode, 'Pincode *', type: TextInputType.number, max: 6, validator: (v) => (v ?? '').trim().length != 6 ? '6 digits' : null)),
          ]),
          field(_state, 'State'),
          const SizedBox(height: 4),
          const Text('Receiver details', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          field(_name, 'Receiver name *', validator: _req, icon: Icons.person_outline),
          field(_phone, 'Phone number *',
              type: TextInputType.phone, max: 10, icon: Icons.phone_outlined, validator: (v) => (v ?? '').trim().length != 10 ? 'Enter 10-digit number' : null),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _default,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _default = v),
            title: const Text('Make this my default address'),
          ),
        ]),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Save Address'),
        ),
      ),
    );
  }
}
