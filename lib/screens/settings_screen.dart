import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final String title;
  final double currentLimit;
  final double currentMaxGaugeValue;

  const SettingsScreen({
    super.key,
    required this.title,
    required this.currentLimit,
    required this.currentMaxGaugeValue,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _limitController;
  late TextEditingController _maxGaugeController;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(text: widget.currentLimit.toString());
    _maxGaugeController = TextEditingController(text: widget.currentMaxGaugeValue.toString());
  }

  @override
  void dispose() {
    _limitController.dispose();
    _maxGaugeController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final limit = double.tryParse(_limitController.text) ?? widget.currentLimit;
    final maxGauge = double.tryParse(_maxGaugeController.text) ?? widget.currentMaxGaugeValue;
    
    // Return the result to the previous screen
    Navigator.pop(context, {'limit': limit, 'maxGauge': maxGauge});
  }

  @override
  Widget build(BuildContext context) {
    // Extract parameter name from title (e.g., "CMD Settings" -> "CMD")
    final paramName = widget.title.split(' ').first;
    // Determine unit based on parameter
    final unit = paramName == 'POWER' ? 'kW' : 'kVA';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFB), // Very light bluish-grey background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adjust $paramName Parameters',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              label: 'Limit ($unit)',
              icon: Icons.speed,
              controller: _limitController,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'Max Gauge Value',
              icon: Icons.linear_scale, // Approximate icon for max gauge
              controller: _maxGaugeController,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3), // Bright blue
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'SAVE SETTINGS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.black54),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
