import 'dart:async';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'settings_screen.dart';
import 'pcc_details_screen.dart';
import '../services/api_service.dart';
import '../services/alert_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  // CMD State
  double cmdLimit = 800.0;
  double cmdMaxGauge = 800.0; 

  // Power State
  double powerLimit = 150.0;
  double powerMaxGauge = 300.0;

  // Live Values
  double liveKva = 0.0;
  double powerValue = 0.0;
  double totalUnitReadings = 0.0;
  double powerFactor = 0.0;
  final double pfLimit = 0.990;
  
  // Requires DB
  final double todayUnits = 0.0;
  final double consumedUnits = 0.0;
  DateTime _selectedDate = DateTime(DateTime.now().year, 5, 21); // Default to May 21

  int _currentIndex = 0;
  Timer? _timer;
  bool _isLoading = true;
  bool _isRefreshing = false;
  Map<String, dynamic>? _apiData;
  bool _alertShown = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    AlertService.stopAlert();
    try {
      ScaffoldMessenger.of(context).clearMaterialBanners();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _fetchData({bool isBackground = false}) async {
    if (isBackground) {
      if (mounted) setState(() { _isRefreshing = true; });
    } else {
      if (mounted) setState(() { _isLoading = true; });
    }

    try {
      final data = await ApiService.fetchSensorData();
      final settings = await ApiService.fetchSettings();

      if (mounted) {
        setState(() {
          if (data != null) {
            _apiData = data;
            _calculateAggregates();
          }
          if (settings != null) {
            cmdLimit = (settings['cmdLimit'] ?? cmdLimit).toDouble();
            cmdMaxGauge = (settings['cmdMaxGauge'] ?? cmdMaxGauge).toDouble();
            powerLimit = (settings['powerLimit'] ?? powerLimit).toDouble();
            powerMaxGauge = (settings['powerMaxGauge'] ?? powerMaxGauge).toDouble();
          }
          _isLoading = false;
          _isRefreshing = false;
        });
        if (data != null) _checkAlerts();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _checkAlerts() {
    bool isCmdExceeded = liveKva > cmdLimit;

    if (isCmdExceeded) {
      if (!_alertShown && !_isMuted) {
        _alertShown = true;
        AlertService.playAlert();
      }
    } else {
      if (_alertShown || _isMuted) {
        _alertShown = false;
        _isMuted = false;
        AlertService.stopAlert();
      }
    }
  }

  Widget _buildInlineBanner(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8E8), // Very light red
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0A8A8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _isMuted ? null : () {
              setState(() {
                _isMuted = true;
                AlertService.stopAlert();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMuted ? Colors.grey : const Color(0xFFEF5350), // Grey when muted, otherwise Red
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 0),
            ),
            child: Text(_isMuted ? 'STOPPED' : 'STOP', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _calculateAggregates() {
    if (_apiData == null) return;
    
    double sumKva = 0;
    double sumKw = 0;
    double sumKwh = 0;
    
    final mainMeterSuffixes = ['6', '108', '201'];
    
    for (var suffix in mainMeterSuffixes) {
      sumKva += double.tryParse(_apiData!['Total_KVA_meter_$suffix']?.toString() ?? '0') ?? 0;
      sumKw += double.tryParse(_apiData!['Total_KW_meter_$suffix']?.toString() ?? '0') ?? 0;
      sumKwh += double.tryParse(_apiData!['TotalNet_KWH_meter_$suffix']?.toString() ?? '0') ?? 0;
    }
    
    liveKva = sumKva;
    powerValue = sumKw;
    totalUnitReadings = sumKwh;
    powerFactor = liveKva > 0 ? (powerValue / liveKva).abs() : 0.0;
  }

  void _openSettings(String title, double currentLimit, double currentMax, Function(double, double) onSave) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          title: title,
          currentLimit: currentLimit,
          currentMaxGaugeValue: currentMax,
        ),
      ),
    );

    if (result != null && result is Map<String, double>) {
      double newLimit = result['limit']!;
      double newMaxGauge = result['maxGauge']!;
      setState(() {
        onSave(newLimit, newMaxGauge);
      });

      // Prepare settings payload
      Map<String, dynamic> settingsPayload = {};
      if (title.startsWith('CMD')) {
        settingsPayload['cmdLimit'] = newLimit;
        settingsPayload['cmdMaxGauge'] = newMaxGauge;
      } else if (title.startsWith('POWER')) {
        settingsPayload['powerLimit'] = newLimit;
        settingsPayload['powerMaxGauge'] = newMaxGauge;
      }

      // Update on MongoDB backend
      if (settingsPayload.isNotEmpty) {
        bool success = await ApiService.updateSettings(settingsPayload);
        if (mounted && !success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to sync settings with server.')),
          );
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4DB6AC), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.jpg'),
        ),
        title: const Column(
          children: [
            Text(
              'Vishnu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Campus Energy Monitoring System',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.blue),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_alertShown && liveKva > cmdLimit)
                      _buildInlineBanner('CMD Limit Exceeded: ${liveKva.toStringAsFixed(2)} > ${cmdLimit.toStringAsFixed(1)}'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openSettings('CMD Settings', cmdLimit, cmdMaxGauge, (limit, maxGauge) {
                              cmdLimit = limit;
                              cmdMaxGauge = maxGauge;
                            }),
                            child: _buildGaugeColumn(
                              title: 'CMD (Live kVA)',
                              limitText: 'Limit: ${cmdLimit.toStringAsFixed(1)} kVA',
                              valueText: '${liveKva.toStringAsFixed(2)} kVA',
                              value: liveKva,
                              maxValue: cmdMaxGauge,
                              limit: cmdLimit,
                              limitColor: const Color(0xFFFFF3E0), // Light orange
                              limitTextColor: const Color(0xFFFFB74D), // Orange text
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openSettings('POWER Settings', powerLimit, powerMaxGauge, (limit, maxGauge) {
                              powerLimit = limit;
                              powerMaxGauge = maxGauge;
                            }),
                            child: _buildGaugeColumn(
                              title: 'POWER (Live kW)',
                              limitText: 'Limit: ${powerLimit.toStringAsFixed(1)} kW',
                              valueText: '${powerValue.toStringAsFixed(2)} kW',
                              value: powerValue,
                              maxValue: powerMaxGauge,
                              limit: powerLimit,
                              limitColor: const Color(0xFFFFF3E0), // Light orange
                              limitTextColor: const Color(0xFFFFB74D), // Orange text
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildGreenStatsGrid(),
                    const SizedBox(height: 16),
                    _buildWhiteStatsGrid(),
                    const SizedBox(height: 24),
                    _buildPccSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF4DB6AC), // Teal green
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Monitoring',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeColumn({
    required String title,
    required String limitText,
    required String valueText,
    required double value,
    required double maxValue,
    required double limit,
    required Color limitColor,
    required Color limitTextColor,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: limitColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            limitText,
            style: TextStyle(
              color: limitTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: _buildRadialGauge(value: value, maxValue: maxValue),
        ),
        Text(
          valueText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRadialGauge({required double value, required double maxValue}) {
    double range1End = maxValue * 0.6;
    double range2End = maxValue * 0.85;

    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: maxValue,
          showLabels: true,
          showTicks: false,
          axisLineStyle: const AxisLineStyle(
            thickness: 0.15,
            thicknessUnit: GaugeSizeUnit.factor,
          ),
          ranges: <GaugeRange>[
            GaugeRange(
              startValue: 0,
              endValue: range1End,
              color: const Color(0xFF4CAF50), // Green
              startWidth: 0.15,
              endWidth: 0.15,
              sizeUnit: GaugeSizeUnit.factor,
            ),
            GaugeRange(
              startValue: range1End,
              endValue: range2End,
              color: const Color(0xFFFFEB3B), // Yellow
              startWidth: 0.15,
              endWidth: 0.15,
              sizeUnit: GaugeSizeUnit.factor,
            ),
            GaugeRange(
              startValue: range2End,
              endValue: maxValue,
              color: const Color(0xFFF44336), // Red
              startWidth: 0.15,
              endWidth: 0.15,
              sizeUnit: GaugeSizeUnit.factor,
            ),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(
              value: value,
              needleLength: 0.6,
              lengthUnit: GaugeSizeUnit.factor,
              needleColor: Colors.black87,
              knobStyle: const KnobStyle(
                knobRadius: 0.08,
                color: Colors.black87,
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildGreenStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFA5E0C2), // Light green background
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildStatItem('LIVE KVA', liveKva.toStringAsFixed(2))),
              const SizedBox(width: 16),
              Expanded(child: _buildStatItem('TOTAL UNIT READINGS', totalUnitReadings.toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('POWER FACTOR', powerFactor.toStringAsFixed(3)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatItem('P.F LIMIT', pfLimit.toStringAsFixed(3)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItemWithSubtitle(
              'TODAY UNITS',
              '0.0', // Requires DB
              '12AM - Now',
              Colors.grey,
            ),
          ),
          Container(width: 1, height: 60, color: Colors.grey.withOpacity(0.2)),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(context),
              child: _buildStatItemWithSubtitle(
                'CONSUMED UNITS',
                totalUnitReadings.toStringAsFixed(1), // Show real total readings as a proxy for now
                'From ${_selectedDate.day} ${_getMonthName(_selectedDate.month)} (Tap)',
                Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Widget _buildStatItemWithSubtitle(String label, String value, String subtitle, Color subtitleColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11,
            color: subtitleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPccSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Power Control Centers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildPccButton('PCC1')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPccButton('PCC2')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildPccButton('PCC3')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildPccButton('PCC 3A')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPccButton(String title) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PCCDetailsScreen(title: title)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFA5E0C2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
