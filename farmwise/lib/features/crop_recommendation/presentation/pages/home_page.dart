import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Added
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/inference_service.dart';
import '../../../weather/data/weather_service.dart';
import '../../../history/data/history_service.dart';
import 'crop_guide_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final _inferenceService = GetIt.I<InferenceService>();
  final _weatherService = GetIt.I<WeatherService>();
  final _historyService = GetIt.I<HistoryService>();

  late TabController _tabController;

  String? _prediction;
  bool _isLoading = true;
  bool _isFetchingWeather = false;
  List<Map<String, dynamic>> _history = [];

  // Only soil parameters - weather is auto-fetched
  final List<String> _features = ['N', 'P', 'K', 'ph'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (var feature in _features) {
      _controllers[feature] = TextEditingController();
    }
    _initData();
  }

  Future<void> _initData() async {
    try {
      await _inferenceService.init();
      await _historyService.init();
      _loadHistory();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error initializing: $e')));
      }
    }
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'FarmWise',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Recommend', icon: Icon(Icons.psychology)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildRecommendationTab(), _buildHistoryTab()],
            ),
    );
  }

  Widget _buildRecommendationTab() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input Form First
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(
                      'Enter Soil & Weather Details',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ..._features.map(_buildInputField),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isFetchingWeather ? null : _predict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _isFetchingWeather
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Get Recommendation',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Inline result preview card (shows after first prediction)
          if (_prediction != null) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[700]!],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withAlpha(60),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showResultBottomSheet(_prediction!),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/crops/${_prediction!.toLowerCase()}.webp',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.eco, color: Colors.green[700]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Last Recommendation',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _prediction!.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 60, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(
              'No recommendations yet',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your crop recommendations will appear here',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final date = DateTime.parse(item['date']);
        final crop = item['crop'].toString();
        final cropLower = crop.toLowerCase();

        // Time ago formatting
        final now = DateTime.now();
        final diff = now.difference(date);
        String timeAgo;
        if (diff.inDays > 0) {
          timeAgo = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgo = '${diff.inHours}h ago';
        } else {
          timeAgo = '${diff.inMinutes}m ago';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.green[50]!, Colors.green[100]!.withAlpha(50)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showResultBottomSheet(
                  crop,
                  savedPlantingAdvice: item['planting_advice'] as String?,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Crop image
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green[200]!,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/crops/$cropLower.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.green[100],
                              child: Icon(
                                Icons.grass,
                                color: Colors.green[700],
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  crop.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    timeAgo,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['details'] ?? 'No parameters',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey[700],
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Planting advice badge
                            if (item['planting_advice'] != null &&
                                (item['planting_advice'] as String)
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['planting_advice'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: Colors.green[400]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _seasonalForecast = [];
  bool _isFetchingForecast = false;

  Future<void> _predict() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isFetchingWeather = true);

      try {
        // 1. Fetch weather forecast (90-day average)
        final weather = await _weatherService.getCurrentWeather();

        // 2. Combine soil inputs with fetched weather
        final Map<String, double> inputs = {};
        for (var feature in _features) {
          inputs[feature] = double.parse(_controllers[feature]!.text);
        }
        inputs['temperature'] = weather['temperature']!;
        inputs['humidity'] = weather['humidity']!;
        inputs['rainfall'] = weather['rainfall']!;

        // 3. Run prediction (now async - calls Render API)
        final result = await _inferenceService.predict(inputs);

        // 4. Fetch seasonal forecast for planting advice
        setState(() {
          _isFetchingForecast = true;
        });

        List<Map<String, dynamic>> forecast = [];
        String plantingAdvice = '';
        try {
          final position = await Geolocator.getCurrentPosition();
          forecast = await _weatherService.getSeasonalForecast(
            position.latitude,
            position.longitude,
          );

          // Generate planting advice text from forecast
          if (forecast.isNotEmpty) {
            final wetMonths = forecast
                .where((m) => (m['totalRain'] as double) > 50)
                .toList();
            if (wetMonths.isNotEmpty) {
              final firstWet = wetMonths.first;
              final date = firstWet['month'] as DateTime;
              final monthName = DateFormat('MMMM').format(date);
              final rain = (firstWet['totalRain'] as double).toInt();
              if (date.month == DateTime.now().month ||
                  date.month == DateTime.now().month + 1) {
                plantingAdvice =
                    '🌱 Plant now! $monthName has ~${rain}mm rain.';
              } else {
                plantingAdvice = '⏳ Wait for $monthName (~${rain}mm expected).';
              }
            } else {
              plantingAdvice = '⚠️ Dry season ahead. Irrigation required.';
            }
          }
        } catch (_) {
          // Forecast fetch failed, continue without it
        }

        setState(() {
          _seasonalForecast = forecast;
          _isFetchingForecast = false;
        });

        // 5. Save to history (with planting advice)
        final details =
            'N: ${inputs['N']?.toInt()}, P: ${inputs['P']?.toInt()}, K: ${inputs['K']?.toInt()}\n'
            'Temp: ${inputs['temperature']?.toStringAsFixed(1)}°C, '
            'Hum: ${inputs['humidity']?.toInt()}%\n'
            'pH: ${inputs['ph']?.toStringAsFixed(1)}, '
            'Rain: ${inputs['rainfall']?.toInt()}mm';

        await _historyService.saveRecommendation(
          result,
          details,
          plantingAdvice: plantingAdvice.isNotEmpty ? plantingAdvice : null,
        );
        _loadHistory();

        setState(() {
          _prediction = result;
          _isFetchingWeather = false;
        });

        // 6. Show result in BOTTOM SHEET
        _showResultBottomSheet(result);
      } catch (e) {
        setState(() {
          _isFetchingWeather = false;
          _isFetchingForecast = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _fetchSeasonalForecast() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final forecast = await _weatherService.getSeasonalForecast(
        position.latitude,
        position.longitude,
      );
      if (mounted) {
        setState(() {
          _seasonalForecast = forecast;
          _isFetchingForecast = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _seasonalForecast = [];
          _isFetchingForecast = false;
        });
      }
    }
  }

  void _showResultBottomSheet(
    String prediction, {
    String? savedPlantingAdvice,
  }) {
    final cropName = prediction.toLowerCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
      builder: (context) {
        return _ResultBottomSheet(
          cropName: cropName,
          seasonalForecast: _seasonalForecast,
          isFetchingForecast: _isFetchingForecast,
          savedPlantingAdvice: savedPlantingAdvice,
          onViewGuide: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CropGuidePage(
                  cropName: cropName,
                  seasonalForecast: _seasonalForecast,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ... (Build method remains same)

  Widget _buildResultCard(String prediction) {
    final cropName = prediction.toLowerCase();

    return Card(
      color: Colors.green[50], // Light green background
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Recommended Crop',
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.green[900],
                fontWeight: FontWeight.w500,
              ),
            ),
            // ... (Image Container remains same, omitted for brevity in search/replace if not changing)
            const SizedBox(height: 12),
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade200, width: 3),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/crops/$cropName.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.grass,
                      size: 50,
                      color: Colors.green[700],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              prediction.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),

            // Forecast/Planting Window Advice
            if (_isFetchingForecast) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Loading planting window...",
                      style: GoogleFonts.outfit(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ] else if (_seasonalForecast.isNotEmpty) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  // Simple heuristic: Find first month with > 50mm rain
                  final wetMonths = _seasonalForecast
                      .where((m) => (m['totalRain'] as double) > 50)
                      .toList();
                  String advice;
                  Color color;
                  IconData icon;

                  if (wetMonths.isNotEmpty) {
                    final firstWet = wetMonths.first;
                    final date = firstWet['month'] as DateTime;
                    final monthName = DateFormat('MMMM').format(date);

                    // If the first wet month is this month or next
                    if (date.month == DateTime.now().month ||
                        date.month == DateTime.now().month + 1) {
                      advice = "🌱 Best to plant now (Rains in $monthName)";
                      color = Colors.green;
                      icon = Icons.check_circle;
                    } else {
                      advice = "⏳ Wait to plant in $monthName";
                      color = Colors.orange;
                      icon = Icons.hourglass_top;
                    }
                  } else {
                    advice = "⚠️ Dry season ahead. Irrigation required.";
                    color = Colors.amber.shade900;
                    icon = Icons.warning;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            advice,
                            style: GoogleFonts.outfit(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CropGuidePage(
                      cropName: cropName,
                      seasonalForecast: _seasonalForecast, // PASS DATA HERE
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.menu_book),
              label: const Text("View Cultivation Guide"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green[800],
                side: BorderSide(color: Colors.green.shade800),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: _controllers[feature],
        decoration: InputDecoration(
          labelText: _getLabel(feature),
          // suffixText is now redundant if label has info, but good for units
          suffixText: _getUnit(feature),
          helperText: _getHelperText(feature),
          prefixIcon: Icon(_getIcon(feature), color: Colors.green[600]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.green.shade600, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) => _validateInput(value, feature),
      ),
    );
  }

  String? _validateInput(String? value, String feature) {
    if (value == null || value.isEmpty) return 'Required';
    final numVal = double.tryParse(value);
    if (numVal == null) return 'Invalid number';

    switch (feature) {
      case 'ph':
        if (numVal < 0 || numVal > 14) return 'pH must be 0-14';
        break;
      case 'humidity':
        if (numVal < 0 || numVal > 100) return 'Humidity must be 0-100%';
        break;
      case 'temperature':
        if (numVal < 0 || numVal > 100)
          return 'Temperature must be between 0-100°C';
        break;
      case 'N':
        if (numVal < 0 || numVal > 200) return 'Value must be between 0-200';
        break;
      case 'P':
        if (numVal < 0 || numVal > 200) return 'Value must be between 0-200';
        break;
      case 'K':
        if (numVal < 0 || numVal > 250) return 'Value must be between 0-250';
        break;
      case 'rainfall':
        if (numVal < 0 || numVal > 500)
          return 'Rainfall must be between 0-500mm';
        break;
    }
    return null;
  }

  String _getLabel(String feature) {
    switch (feature) {
      case 'N':
        return 'Nitrogen (N)';
      case 'P':
        return 'Phosphorus (P)';
      case 'K':
        return 'Potassium (K)';
      case 'ph':
        return 'Soil pH';
      case 'temperature':
        return 'Temperature';
      case 'humidity':
        return 'Humidity';
      case 'rainfall':
        return 'Rainfall';
      default:
        return feature;
    }
  }

  String _getHelperText(String feature) {
    switch (feature) {
      case 'N':
      case 'P':
      case 'K':
        return 'Ratio in soil (kg/ha)';
      case 'ph':
        return 'Scale 0-14';
      case 'temperature':
        return 'Avg. for Season/Month (°C)';
      case 'humidity':
        return 'Avg. Relative Humidity (%)';
      case 'rainfall':
        return 'Total Seasonal Rainfall (mm)';
      default:
        return '';
    }
  }

  IconData _getIcon(String feature) {
    switch (feature) {
      case 'N':
        return Icons.grass;
      case 'P':
        return Icons.science;
      case 'K':
        return Icons.eco_outlined;
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'ph':
        return Icons.opacity;
      case 'rainfall':
        return Icons.cloud;
      default:
        return Icons.input;
    }
  }

  String _getUnit(String feature) {
    switch (feature) {
      case 'temperature':
        return '°C';
      case 'humidity':
        return '%';
      case 'rainfall':
        return 'mm';
      default:
        return '';
    }
  }
}

// -----------------------------------------------------------------------------
// Result Bottom Sheet Widget with Bouncy Animations
// -----------------------------------------------------------------------------
class _ResultBottomSheet extends StatefulWidget {
  final String cropName;
  final List<Map<String, dynamic>> seasonalForecast;
  final bool isFetchingForecast;
  final VoidCallback onViewGuide;
  final String? savedPlantingAdvice;

  const _ResultBottomSheet({
    required this.cropName,
    required this.seasonalForecast,
    required this.isFetchingForecast,
    required this.onViewGuide,
    this.savedPlantingAdvice,
  });

  @override
  State<_ResultBottomSheet> createState() => _ResultBottomSheetState();
}

class _ResultBottomSheetState extends State<_ResultBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  Map<String, dynamic>? _cropGuide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Bouncy spring animation
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _slideAnimation = Tween<double>(
      begin: 50,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
    _loadCropGuide();
  }

  Future<void> _loadCropGuide() async {
    try {
      final jsonString = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/data/crop_guides.json');
      final Map<String, dynamic> guides = Map<String, dynamic>.from(
        jsonDecode(jsonString),
      );
      if (mounted) {
        setState(() {
          _cropGuide = guides[widget.cropName];
        });
      }
    } catch (e) {
      // Guide not found, that's okay
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _buildPlantingAdvice() {
    // If we have saved advice from history, use it
    if (widget.savedPlantingAdvice != null &&
        widget.savedPlantingAdvice!.isNotEmpty) {
      return widget.savedPlantingAdvice!;
    }

    if (widget.isFetchingForecast) {
      return "Loading planting window...";
    }

    if (widget.seasonalForecast.isEmpty) {
      return "Unable to load forecast data.";
    }

    // Get crop water requirements
    String waterNeed = _cropGuide?['water'] ?? 'Moderate';
    int rainfallThreshold = 50; // Default
    if (waterNeed.toLowerCase().contains('high')) {
      rainfallThreshold = 100;
    } else if (waterNeed.toLowerCase().contains('low') ||
        waterNeed.toLowerCase().contains('very low')) {
      rainfallThreshold = 20;
    }

    // Find best month based on crop's water needs
    final wetMonths = widget.seasonalForecast
        .where((m) => (m['totalRain'] as double) >= rainfallThreshold)
        .toList();

    if (wetMonths.isNotEmpty) {
      final bestMonth = wetMonths.first;
      final date = bestMonth['month'] as DateTime;
      final monthName = DateFormat('MMMM').format(date);
      final expectedRain = (bestMonth['totalRain'] as double).toInt();

      if (date.month == DateTime.now().month ||
          date.month == DateTime.now().month + 1) {
        return "🌱 Plant now! $monthName has ~${expectedRain}mm rain.\n"
            "${widget.cropName.toUpperCase()} needs: $waterNeed water.";
      } else {
        return "⏳ Wait for $monthName (~${expectedRain}mm expected).\n"
            "${widget.cropName.toUpperCase()} needs: $waterNeed water.";
      }
    } else {
      return "⚠️ Dry season ahead (next 3 months < ${rainfallThreshold}mm/month).\n"
          "${widget.cropName.toUpperCase()} needs: $waterNeed water.\n"
          "Consider irrigation or drought-resistant varieties.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(scale: _scaleAnimation.value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Success icon with pop animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        size: 48,
                        color: Colors.green[600],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Recommended Crop',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),

              // Crop name with bounce
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves
                    .easeOutBack, // Changed from elasticOut to prevent overshoot
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.5 + (value * 0.5),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0), // Clamp to valid range
                      child: Text(
                        widget.cropName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Crop image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/crops/${widget.cropName}.webp',
                  height: 120,
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.grass,
                      size: 50,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Planting window advice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isFetchingForecast
                      ? Colors.grey[100]
                      : (_buildPlantingAdvice().contains('Plant now')
                            ? Colors.green[50]
                            : Colors.orange[50]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isFetchingForecast
                        ? Colors.grey[300]!
                        : (_buildPlantingAdvice().contains('Plant now')
                              ? Colors.green[300]!
                              : Colors.orange[300]!),
                  ),
                ),
                child: widget.isFetchingForecast
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Analyzing weather forecast...",
                            style: GoogleFonts.outfit(color: Colors.grey[600]),
                          ),
                        ],
                      )
                    : Text(
                        _buildPlantingAdvice(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          height: 1.4,
                          color: _buildPlantingAdvice().contains('Plant now')
                              ? Colors.green[800]
                              : Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.outfit(color: Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: widget.onViewGuide,
                      icon: const Icon(Icons.menu_book, size: 20),
                      label: Text(
                        'Cultivation Guide',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
