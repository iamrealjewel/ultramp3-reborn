import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/core/theme/app_theme.dart';
import 'package:ultramp3/core/services/media_query_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Timer _timer;
  String _timeString = '00:00:00';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = 
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    if (mounted) {
      setState(() {
        _timeString = formattedTime;
      });
    }
  }

  // Realistic S60 Media Scanning Simulator Dialogue
  void _triggerLibraryScan(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _MediaScanDialog();
      },
    );
  }

  void _triggerSleepTimer(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.obsidianDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.electricCyan, width: 1),
        ),
        content: const Text(
          'SLEEP TIMER SCHEDULED FOR 30 MINUTES',
          style: TextStyle(color: AppColors.electricCyan, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExtension = theme.extension<AppThemeExtension>()!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              Color(0xFF12121F),
              AppColors.voidBlack,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium top bar title
              SliverAppBar(
                title: Text(
                  'ULTRAMP3',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: AppColors.neonGreen,
                    letterSpacing: 2.0,
                  ),
                ),
                floating: true,
                pinned: false,
              ),

              // Digital Clock Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          _timeString,
                          style: themeExtension.digitalClockStyle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'OFFLINE ENGINE ACTIVE',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.electricCyan,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Quick Actions Interactive Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildGlassCard(
                          icon: Icons.qr_code_scanner_rounded,
                          title: 'Library Scan',
                          subtitle: 'Index local files',
                          accentColor: AppColors.neonGreen,
                          onTap: () => _triggerLibraryScan(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGlassCard(
                          icon: Icons.timer_outlined,
                          title: 'Sleep Timer',
                          subtitle: 'Auto-stop engine',
                          accentColor: AppColors.electricCyan,
                          onTap: () => _triggerSleepTimer(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recently Played Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RECENTLY PLAYED',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          letterSpacing: 1.0,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'View All',
                          style: TextStyle(color: AppColors.electricCyan, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recently Played horizontal list
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 160,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return _buildRecentTrackCard(index);
                    },
                  ),
                ),
              ),

              // Favorites Snippet Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    'FAVORITE CHANNELS',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),

              // Favorites vertical mockup list
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, kBottomNavigationBarHeight + 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildFavoriteListTile(index);
                    },
                    childCount: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: AppColors.obsidianDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accentColor, size: 28),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTrackCard(int index) {
    final titles = ['Neurodancer', 'Cybernetic Pulse', 'Neon Dreams', 'Laser Voyager', 'Vektor Force'];
    final artists = ['Tokyo Grid', 'Synth Racer', 'Vector Boy', 'Hologram City', 'Pixel Gladiator'];

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.08), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album Art Frame
          Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.obsidianDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: const Border(bottom: BorderSide(color: AppColors.glassBorder, width: 0.5)),
            ),
            child: Icon(
              Icons.music_video_rounded,
              color: AppColors.textMuted.withOpacity(0.4),
              size: 40,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[index],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  artists[index],
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteListTile(int index) {
    final titles = ['Retro Overdrive', 'Vector Horizon', 'Outrun Skyline'];
    final durations = ['4:32', '3:58', '5:12'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.05), width: 0.8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.obsidianDark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.music_note, color: AppColors.cyberPink, size: 20),
        ),
        title: Text(
          titles[index],
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          'UltraMP3 Synthwave Syndicate',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              durations[index],
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.favorite_rounded, color: AppColors.cyberPink, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Skeuomorphic Retro Scan Dialogue Widget
// ---------------------------------------------------------

class _MediaScanDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MediaScanDialog> createState() => _MediaScanDialogState();
}

class _MediaScanDialogState extends ConsumerState<_MediaScanDialog> {
  int _percentage = 0;
  String _scanLog = 'INITIALIZING ENGINE...';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSimulatedScan();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startSimulatedScan() async {
    // Actually trigger the real scan in the background
    final mediaQuery = ref.read(mediaQueryServiceProvider);
    final songs = await mediaQuery.getSongs();
    ref.invalidate(physicalSongsProvider);

    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _percentage += 3;
        
        if (_percentage >= 100) {
          _percentage = 100;
          _scanLog = 'SCAN SUCCESSFUL: ${songs.length} TRACKS INDEXED!';
          timer.cancel();
          // Delay closing dialog to let user enjoy success status
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) Navigator.pop(context);
          });
        } else if (_percentage > 85) {
          _scanLog = 'INDEXING META TAGS...';
        } else if (_percentage > 60 && songs.isNotEmpty) {
          _scanLog = 'INDEXING: ${songs[songs.length % 3].filePath}';
        } else if (_percentage > 40 && songs.length > 1) {
          _scanLog = 'INDEXING: ${songs[1].filePath}';
        } else if (_percentage > 20) {
          _scanLog = 'READING DIRECTORY FILE HANDLES...';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.obsidianDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.neonGreen, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SCANNING STORAGE',
                  style: TextStyle(
                    color: AppColors.neonGreen,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '$_percentage%',
                  style: const TextStyle(
                    color: AppColors.neonGreen,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Retro Digital LED Progress Bar
            Container(
              height: 16,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.neonGreen.withOpacity(0.3), width: 1),
              ),
              padding: const EdgeInsets.all(2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _percentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.neonGreen,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(color: AppColors.neonGreen.withOpacity(0.5), blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Console diagnostics log
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Text(
                _scanLog,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
