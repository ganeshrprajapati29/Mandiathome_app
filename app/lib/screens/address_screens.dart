import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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
                        child: Icon(a.label == 'Home' ? Icons.home_outlined : a.label == 'Work' ? Icons.work_outline : Icons.location_on_outlined, color: AppColors.primary),
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
  const AddressFormScreen({super.key, this.address});
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
  late bool _default = widget.address?.isDefault ?? false;
  bool _saving = false;

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
      isDefault: _default,
    );
    try {
      final auth = context.read<AuthProvider>();
      widget.address == null ? await auth.addAddress(a) : await auth.updateAddress(widget.address!.id, a);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String hint, {String? Function(String?)? validator, TextInputType? type, int? max, IconData? icon}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            validator: validator,
            keyboardType: type,
            maxLength: max,
            inputFormatters: type == TextInputType.number || type == TextInputType.phone ? [FilteringTextInputFormatter.digitsOnly] : null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: hint, counterText: '', prefixIcon: icon != null ? Icon(icon, size: 20) : null),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(widget.address == null ? 'Add address' : 'Edit address')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Save address as', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: ['Home', 'Work', 'Other']
                .map((l) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(l),
                        selected: _label == l,
                        onSelected: (_) => setState(() => _label = l),
                        selectedColor: AppColors.soft,
                        showCheckmark: false,
                        side: BorderSide(color: _label == l ? AppColors.primary : AppColors.border),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          field(_name, 'Receiver name *', validator: _req, icon: Icons.person_outline),
          field(_phone, 'Phone number *', type: TextInputType.phone, max: 10, icon: Icons.phone_outlined,
              validator: (v) => (v ?? '').trim().length != 10 ? 'Enter 10-digit number' : null),
          field(_line1, 'House / Flat no., Building *', validator: _req, icon: Icons.home_outlined),
          field(_line2, 'Street, Area, Colony'),
          field(_landmark, 'Landmark (optional)'),
          Row(children: [
            Expanded(child: field(_city, 'City *', validator: _req)),
            const SizedBox(width: 12),
            Expanded(child: field(_pincode, 'Pincode *', type: TextInputType.number, max: 6, validator: (v) => (v ?? '').trim().length != 6 ? '6 digits' : null)),
          ]),
          field(_state, 'State'),
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
        child: ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Save Address')),
      ),
    );
  }
}
