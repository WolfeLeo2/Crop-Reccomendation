import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CropGuidePage extends StatefulWidget {
  final String cropName;

  const CropGuidePage({super.key, required this.cropName});

  @override
  State<CropGuidePage> createState() => _CropGuidePageState();
}

class _CropGuidePageState extends State<CropGuidePage> {
  Map<String, dynamic>? _guideData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/crop_guides.json',
      );
      final Map<String, dynamic> data = json.decode(response);
      final cropKey = widget.cropName.toLowerCase().replaceAll(' ', '');

      // Handle special naming cases if any, or fuzzy match
      // For now, assume keys in JSON match cropName.toLowerCase()
      // Note: JSON keys are like "rice", "maize". input cropName might be "Rice".

      if (mounted) {
        setState(() {
          _guideData =
              data[cropKey] ??
              data.values.firstWhere(
                (v) => v['name'].toString().toLowerCase() == cropKey,
                orElse: () => null,
              );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading guide: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.cropName.toUpperCase(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _guideData == null
          ? Center(
              child: Text(
                'No guide available for ${widget.cropName}',
                style: GoogleFonts.outfit(fontSize: 18),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Hero(
                    tag: 'crop_image_${widget.cropName}',
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green, width: 0),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/crops/${widget.cropName.toLowerCase()}.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Icon(
                            Icons.grass,
                            size: 60,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    "Season",
                    _guideData!['season'],
                    Icons.calendar_month,
                  ),
                  _buildSection("Soil", _guideData!['soil'], Icons.grass),
                  _buildSection(
                    "Water",
                    _guideData!['water'],
                    Icons.water_drop,
                  ),
                  _buildSection(
                    "Temperature",
                    _guideData!['temperature'],
                    Icons.thermostat,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Cultivation Tips",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_guideData!['tips'] as List).map(
                    (tip) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tip,
                              style: GoogleFonts.outfit(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, String value, IconData icon) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.green[800]),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
        ),
        subtitle: Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
