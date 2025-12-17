import 'package:flutter/material.dart';
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

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
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

  final List<String> _features = [
    'N',
    'P',
    'K',
    'temperature',
    'humidity',
    'ph',
    'rainfall',
  ];

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

  Future<void> _fetchWeather() async {
    setState(() {
      _isFetchingWeather = true;
    });

    try {
      final weather = await _weatherService.getCurrentWeather();

      setState(() {
        _controllers['temperature']?.text = weather['temperature']!.toString();
        _controllers['humidity']?.text = weather['humidity']!.toString();
        if (weather['rainfall']! > 0) {
          _controllers['rainfall']?.text = weather['rainfall']!.toString();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Weather data updated!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Weather Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingWeather = false;
        });
      }
    }
  }

  final _scrollController = ScrollController(); // Add ScrollController

  // ...

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose(); // Dispose ScrollController
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _predict() async {
    if (_formKey.currentState!.validate()) {
      try {
        final Map<String, double> inputs = {};
        for (var feature in _features) {
          inputs[feature] = double.parse(_controllers[feature]!.text);
        }

        final result = _inferenceService.predict(inputs);

        // Save to history with all parameters
        final details =
            'N: ${inputs['N']?.toInt()}, P: ${inputs['P']?.toInt()}, K: ${inputs['K']?.toInt()}\n'
            'Temp: ${inputs['temperature']?.toStringAsFixed(1)}°C, '
            'Hum: ${inputs['humidity']?.toInt()}%\n'
            'pH: ${inputs['ph']?.toStringAsFixed(1)}, '
            'Rain: ${inputs['rainfall']?.toInt()}mm';

        await _historyService.saveRecommendation(result, details);
        _loadHistory();

        setState(() {
          _prediction = result;
        });

        // Auto-scroll to bottom after a slight delay to allow rendering
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error predicting: $e')));
        }
      }
    }
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
        actions: [
          IconButton(
            icon: _isFetchingWeather
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_sync),
            tooltip: 'Get Current Weather',
            onPressed: _isFetchingWeather ? null : _fetchWeather,
          ),
        ],
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
                        onPressed: _predict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
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

          // Result Card Second (if prediction exists)
          if (_prediction != null) ...[
            const SizedBox(height: 20),
            _buildResultCard(_prediction!),
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
            Icon(Icons.history, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _history[index];
        final date = DateTime.parse(item['date']);
        final formattedDate = DateFormat('MMM d, y • h:mm a').format(date);
        final crop = item['crop'].toString().toUpperCase();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              backgroundImage: AssetImage(
                'assets/crops/${crop.toLowerCase()}.webp',
              ),
              onBackgroundImageError: (_, __) {},
              child:
                  null, // We assume the asset exists or error builder handles it visually if we used Image widget, but for CircleAvatar we just let it fail gracefully or show default?
              // Actually CircleAvatar doesn't have an easy fallback child if background fails unless we handle it proactively.
              // Better approach: Use a child Image/Icon if we want strict fallback, but User asked for local assets.
            ),
            title: Text(
              crop,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(formattedDate),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              Text(
                'Parameters:',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['details'] ?? 'No parameters saved',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CropGuidePage(cropName: crop.toLowerCase()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text("View Cultivation Guide"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green[800],
                    side: BorderSide(color: Colors.green.shade800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CropGuidePage(cropName: cropName),
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
