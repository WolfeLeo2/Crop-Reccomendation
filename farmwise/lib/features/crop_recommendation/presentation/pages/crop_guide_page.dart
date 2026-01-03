import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class CropGuidePage extends StatefulWidget {
  final String cropName;
  final List<Map<String, dynamic>>? seasonalForecast;

  const CropGuidePage({
    super.key,
    required this.cropName,
    this.seasonalForecast,
  });

  @override
  State<CropGuidePage> createState() => _CropGuidePageState();
}

class _CropGuidePageState extends State<CropGuidePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _guideData;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGuide();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGuide() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/crop_guides.json',
      );
      final Map<String, dynamic> data = json.decode(response);
      final cropKey = widget.cropName.toLowerCase().replaceAll(' ', '');

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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _guideData == null
          ? _buildNotFound()
          : _buildContent(),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No guide for ${widget.cropName}',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Collapsing App Bar with Hero Image
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              _guideData!['name'] ?? widget.cropName.toUpperCase(),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                Image.asset(
                  'assets/crops/${widget.cropName.toLowerCase()}.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.green[400]!, Colors.green[700]!],
                      ),
                    ),
                    child: Icon(Icons.eco, size: 100, color: Colors.white38),
                  ),
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(180)],
                    ),
                  ),
                ),
                // Scientific name badge
                Positioned(
                  bottom: 60,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _guideData!['scientificName'] ?? '',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tab Bar
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverTabBarDelegate(
            TabBar(
              controller: _tabController,
              labelColor: Colors.green[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.green[700],
              indicatorWeight: 3,
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Overview', icon: Icon(Icons.info_outline, size: 20)),
                Tab(text: 'Growing', icon: Icon(Icons.grass, size: 20)),
                Tab(
                  text: 'Tips',
                  icon: Icon(Icons.lightbulb_outline, size: 20),
                ),
              ],
            ),
          ),
        ),

        // Tab Content
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildGrowingTab(),
              _buildTipsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'About',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _guideData!['description'] ?? 'No description available.',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick stats grid
          Text(
            'Quick Facts',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                Icons.calendar_month,
                'Season',
                _guideData!['season'] ?? '-',
                Colors.orange,
              ),
              _buildStatCard(
                Icons.timer,
                'Duration',
                _guideData!['duration'] ?? '-',
                Colors.blue,
              ),
              _buildStatCard(
                Icons.thermostat,
                'Temperature',
                _guideData!['temperature'] ?? '-',
                Colors.red,
              ),
              _buildStatCard(
                Icons.water_drop,
                'Water Need',
                _guideData!['water'] ?? '-',
                Colors.cyan,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Soil requirements
          _buildRequirementCard(
            icon: Icons.landscape,
            title: 'Soil Requirements',
            value: _guideData!['soil'] ?? '-',
            color: Colors.brown,
            description: 'Optimal soil type and pH for healthy growth.',
          ),
          const SizedBox(height: 16),

          // Water requirements with visual bar
          _buildRequirementCard(
            icon: Icons.water_drop,
            title: 'Water Requirements',
            value: _guideData!['water'] ?? '-',
            color: Colors.blue,
            description: 'Amount of irrigation or rainfall needed.',
            showWaterBar: true,
          ),
          const SizedBox(height: 16),

          // Temperature range
          _buildRequirementCard(
            icon: Icons.thermostat,
            title: 'Temperature Range',
            value: _guideData!['temperature'] ?? '-',
            color: Colors.deepOrange,
            description: 'Ideal temperature for optimal growth.',
          ),
          const SizedBox(height: 16),

          // Growing season
          _buildRequirementCard(
            icon: Icons.calendar_today,
            title: 'Best Planting Season',
            value: _guideData!['season'] ?? '-',
            color: Colors.green,
            description: 'Recommended planting windows.',
          ),
        ],
      ),
    );
  }

  Widget _buildTipsTab() {
    final tips = _guideData!['tips'] as List? ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tips.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tips[index],
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required String description,
    bool showWaterBar = false,
  }) {
    // Calculate water level for visual bar
    double waterLevel = 0.5;
    if (showWaterBar) {
      final waterStr = value.toLowerCase();
      if (waterStr.contains('high'))
        waterLevel = 0.9;
      else if (waterStr.contains('moderate'))
        waterLevel = 0.6;
      else if (waterStr.contains('low'))
        waterLevel = 0.3;
      else if (waterStr.contains('very low'))
        waterLevel = 0.15;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color.withAlpha(220),
              ),
            ),
          ),
          if (showWaterBar) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: waterLevel,
                minHeight: 8,
                backgroundColor: Colors.blue[100],
                valueColor: AlwaysStoppedAnimation(Colors.blue[600]),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Low',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  'High',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Custom delegate for sticky tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.grey[50], child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
