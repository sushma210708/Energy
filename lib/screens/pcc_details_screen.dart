import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MeterConfig {
  final String name;
  final String apiSuffix;

  MeterConfig(this.name, this.apiSuffix);
}

class PCCDetailsScreen extends StatefulWidget {
  final String title;

  const PCCDetailsScreen({super.key, required this.title});

  @override
  State<PCCDetailsScreen> createState() => _PCCDetailsScreenState();
}

class _PCCDetailsScreenState extends State<PCCDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _apiData;
  Timer? _timer;
  DateTime? _lastUpdated;
  bool _isRefreshing = false;

  late PageController _pageController;
  late int _currentIndex;
  final List<String> _pccTitles = ['PCC1', 'PCC2', 'PCC3', 'PCC 3A'];
  // Colour mapping for each PCC heading (AppBar title)
  final Map<String, Color> _pccTitleColors = {
    'PCC1': const Color(0xFFAEE9E1), // Aqua Mint
    'PCC2': const Color(0xFFA9D6E5), // Ocean Blue
    'PCC3': const Color(0xFFC8B6E2), // Lavender
    'PCC 3A': const Color(0xFFFFD6A5), // Peach
  };

  Color _getPccTitleColor(String title) => _pccTitleColors[title] ?? Colors.black;

  // Define the mappings for each PCC based on the screenshots
  final List<MeterConfig> _pcc1Meters = [
    MeterConfig('Main Meter', '6'), // mapped to meter_6
    MeterConfig('VIT Library AC\'S', '1'),
    MeterConfig('VIT Library Lighting', '2'),
    MeterConfig('STL Supply', '3'),
    MeterConfig('Vishnu School Panel', '4'),
    MeterConfig('Power Room-2 Supply', '5'),
    MeterConfig('SVECW A Block Lighting', '7'),
    MeterConfig('SVECW Library Lighting', '8'),
    MeterConfig('SVECW C Block Lighting', '9'),
    MeterConfig('A A/C\'S', '10'),
    MeterConfig('B A/C\'S', '11'),
    MeterConfig('C A/C\'S', '12'),
  ];

  final List<MeterConfig> _pcc2Meters = [
    MeterConfig('Main Meter', '108'),
    MeterConfig('VIT Block 2 Lighting', '101'),
    MeterConfig('VIT Block 1 Lighting', '102'),
    MeterConfig('VIT Block-2 A/C\'s', '103'),
    MeterConfig('VIT Block-4 lighting', '104'),
    MeterConfig('VIT Block-4 A/C\'s', '105'),
    MeterConfig('4th Phase Main Panel Supply', '106'),
    MeterConfig('Power House-2', '107'),
    MeterConfig('Seetha Canteen Lighting', '109'),
    MeterConfig('53 rooms lighting supply', '110'),
    MeterConfig('8th Hostels Lighting', '112'),
    MeterConfig('Seetha Indoor Audi Lighting', '113'),
    MeterConfig('Medha Hostel', '114'),
    MeterConfig('VIT C block lighting', '115'),
  ];

  final List<MeterConfig> _pcc3Meters = [
    MeterConfig('Main meter', '201'),
    MeterConfig('11F1 800A TPN ACB', '226'),
    MeterConfig('10F1 400A TPN SFU', '222'),
    MeterConfig('10F2 400A TPN SFU', '223'),
    MeterConfig('Womens Ground Panel', '224'),
    MeterConfig('SVECW Seminar Hall', '225'),
    MeterConfig('9F1 400A TPN SFU', '204'),
    MeterConfig('9F2 400A TPN SFU', '205'),
    MeterConfig('9F3 315A TPN SFU', '207'),
    MeterConfig('8F1 400A TPN SFU', '208'),
    MeterConfig('8F2 400A TPN SFU', '212'),
    MeterConfig('8F3 315A TPN SFU', '214'),
    MeterConfig('8F4 250A TPN SFU', '215'),
    MeterConfig('6F1 400A TPN SFU', '210'),
    MeterConfig('6F2 400A TPN SFU', '211'),
    MeterConfig('6F3 315A TPN SFU', '216'),
    MeterConfig('6F4 250A TPN SFU', '213'),
    MeterConfig('Womens Ground Panel A/C', '206'),
    MeterConfig('4F3 315A TPN SFU', '217'),
    MeterConfig('SVECW Seminar Hall AC\'S', '209'),
    MeterConfig('3F1 800A TPN ACB', '218'),
    MeterConfig('3F2 800A TPN ACB', '219'),
    MeterConfig('APRC Panel Supply', '202'),
    MeterConfig('Power Room-1 Loop Supply', '203'),
  ];

  final List<MeterConfig> _pcc3AMeters = [
    MeterConfig('Main meter', '227'),
    MeterConfig('VDC Block 2&3 Lighting', '51'),
    MeterConfig('VDC Block 2&3 AC\'s', '52'),
    MeterConfig('Mini Auditorium AC\'s', '53'),
    MeterConfig('Sumedha Hostel AC\'s', '54'),
    MeterConfig('Sita Auditorium AC\'s', '55'),
    MeterConfig('VDC Girls Hostels', '57'),
    MeterConfig('VDC Block-1 AC\'s', '58'),
    MeterConfig('SVECW Library AC\'s', '61'),
    MeterConfig('CSSD Building', '62'),
    MeterConfig('Medha Hostel Lighting', '64'),
    MeterConfig('Geysers', '63'),
    MeterConfig('Medha Hostel Geysers', '65'),
    MeterConfig('Hostel Geysers VDC', '66'),
  ];

  List<MeterConfig> _getMetersForTitle(String t) {
    if (t == 'PCC1') return _pcc1Meters;
    if (t == 'PCC2') return _pcc2Meters;
    if (t == 'PCC 3A') return _pcc3AMeters;
    if (t == 'PCC3') return _pcc3Meters;
    return _pcc1Meters;
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _pccTitles.indexOf(widget.title);
    _currentIndex = initialIndex == -1 ? 0 : initialIndex;
    final initialPage = 1000 * _pccTitles.length + _currentIndex;
    _pageController = PageController(initialPage: initialPage);

    _fetchData();
    // Auto refresh data every 5 seconds for real-time dashboard updates
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchData(isBackground: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
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
      
      if (data != null) {
        if (mounted) {
          setState(() {
            _apiData = data;
            _isLoading = false;
            _isRefreshing = false;
            _lastUpdated = DateTime.now();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            if (!isBackground) _errorMessage = 'Failed to load data';
            _isLoading = false;
            _isRefreshing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!isBackground) _errorMessage = 'Error connecting to API';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  String _getValue(String prefix, String suffix) {
    if (_apiData == null || suffix.isEmpty) return '0.00';
    final key = '${prefix}_meter_$suffix';
    if (_apiData!.containsKey(key)) {
      final val = _apiData![key];
      if (val is num) {
        return val.toStringAsFixed(2);
      }
      return val.toString();
    }
    return '0.00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFB),
      appBar: AppBar(
        backgroundColor: _getPccTitleColor(_pccTitles[_currentIndex]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _pccTitles[_currentIndex],
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index % _pccTitles.length;
          });
        },
        itemBuilder: (context, index) {
          final realIndex = index % _pccTitles.length;
          return _buildBodyForTitle(_pccTitles[realIndex]);
        },
      ),
    );
  }

  Widget _buildBodyForTitle(String pccTitle) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchData();
              },
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }

    final meters = _getMetersForTitle(pccTitle);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Last updated indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isRefreshing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_isRefreshing) const SizedBox(width: 8),
                Text(
                  _lastUpdated != null
                      ? 'Last synced: ${_lastUpdated!.hour.toString().padLeft(2, '0')}:${_lastUpdated!.minute.toString().padLeft(2, '0')}:${_lastUpdated!.second.toString().padLeft(2, '0')}'
                      : 'Syncing...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Meter', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('kVA', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('kW', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('I1 (A)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13)),
                ),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _getPccTitleColor(pccTitle),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                border: Border(
                  left: BorderSide(color: Colors.black.withOpacity(0.15)),
                  right: BorderSide(color: Colors.black.withOpacity(0.15)),
                  bottom: BorderSide(color: Colors.black.withOpacity(0.15)),
                ),
              ),
              child: ListView.separated(
                itemCount: meters.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.black.withOpacity(0.15)),
                itemBuilder: (context, index) {
                  final meter = meters[index];
                  final kw = _getValue('Total_KW', meter.apiSuffix);
                  final kva = _getValue('Total_KVA', meter.apiSuffix);
                  final current = _getValue('Current_I1', meter.apiSuffix);
                  final pf = _getValue('Avg_PF', meter.apiSuffix);
                  
                  final pfVal = double.tryParse(pf) ?? 0.0;
                  final isPfLow = pfVal.abs() < 0.99 && pfVal.abs() > 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            meter.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _buildValuePill(pccTitle, kva),
                        ),
                        Expanded(
                          flex: 2,
                          child: _buildValuePill(pccTitle, kw),
                        ),
                        Expanded(
                          flex: 2,
                          child: _buildValuePill(pccTitle, current),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuePill(String pccTitle, String value, {bool isWarning = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isWarning ? Colors.red.shade200 : _getPccTitleColor(pccTitle).withOpacity(0.5)),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isWarning ? Colors.red.shade700 : Colors.black,
          fontSize: 12,
        ),
      ),
    );
  }
}
