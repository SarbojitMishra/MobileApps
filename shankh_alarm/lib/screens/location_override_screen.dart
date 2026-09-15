import 'package:flutter/material.dart';

import '../prefs.dart';
import '../theme.dart';

/// Manual reference-location override (ALM-FR-006): lat/lon entry only, no
/// geocoding, so this never introduces a network dependency (Section 6/42
/// OQ-02) — offline-first stays true regardless of this feature.
class LocationOverrideScreen extends StatefulWidget {
  const LocationOverrideScreen({super.key});

  @override
  State<LocationOverrideScreen> createState() => _LocationOverrideScreenState();
}

class _LocationOverrideScreenState extends State<LocationOverrideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _nameController = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    Prefs.getLatitude().then((v) => _latController.text = v.toString());
    Prefs.getLongitude().then((v) => _lonController.text = v.toString());
    Prefs.getLocationName().then((v) {
      if (v != Prefs.defaultLocationName) _nameController.text = v;
    });
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validateLat(String? value) {
    final v = double.tryParse(value ?? '');
    if (v == null) return 'Enter a number';
    if (v < -90 || v > 90) return 'Must be between -90 and 90';
    return null;
  }

  String? _validateLon(String? value) {
    final v = double.tryParse(value ?? '');
    if (v == null) return 'Enter a number';
    if (v < -180 || v > 180) return 'Must be between -180 and 180';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final lat = double.parse(_latController.text);
    final lon = double.parse(_lonController.text);
    final name = _nameController.text.trim().isEmpty
        ? 'Custom location ($lat, $lon)'
        : _nameController.text.trim();
    await Prefs.setLocation(lat, lon, name);
    await Prefs.setUseDeviceLocation(false);
    setState(() => _saved = true);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _resetToDefault() async {
    await Prefs.resetToDefaultLocation();
    setState(() {
      _latController.text = Prefs.defaultLat.toString();
      _lonController.text = Prefs.defaultLon.toString();
      _nameController.clear();
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set location manually')),
      backgroundColor: AppColors.cream,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Enter latitude/longitude directly — no city search, so this '
                'never needs a network connection.',
                style: TextStyle(color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _latController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitude (-90 to 90)'),
                validator: _validateLat,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lonController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitude (-180 to 180)'),
                validator: _validateLon,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Label (optional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.saffron,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: _save,
                child: const Text('Save location'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _resetToDefault,
                child: const Text('Reset to Bhubaneswar default'),
              ),
              if (_saved) ...[
                const SizedBox(height: 16),
                const Text('Saved.', style: TextStyle(color: Colors.green)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
