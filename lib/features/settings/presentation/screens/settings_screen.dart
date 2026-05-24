import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/features/player/presentation/providers/player_settings_provider.dart';
import 'package:ultramp3/core/services/playback_service.dart';
import 'package:ultramp3/core/services/storage_service.dart';
import 'package:ultramp3/core/services/media_query_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _bassValue = 0.5;
  double _midValue = 0.5;
  double _trebleValue = 0.5;
  String _activePreset = 'Flat';

  final Map<String, List<double>> _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.0, 2.5, -1.5, 2.0, 5.0],
    'Pop': [-1.5, 1.5, 3.0, 1.0, -1.0],
    'Jazz': [3.0, 1.5, -1.5, 1.5, 3.0],
    'Bass & Treble': [7.0, 4.0, 0.0, 4.0, 7.0],
    'Mids': [-3.0, -1.0, 6.0, 4.0, -2.0],
    'Classic': [4.5, 3.0, 0.0, 2.5, 4.0],
    'Live': [-1.0, 2.0, 3.0, 3.0, 2.0],
    'Dance': [5.5, 7.0, 3.5, 0.0, 5.0],
    'Soft': [2.5, 1.0, 0.0, 1.5, 3.0],
    'No Bass': [-12.0, -12.0, 0.0, 0.0, 0.0],
    'No Mids': [0.0, 0.0, -12.0, -12.0, 0.0],
    'No Treble': [0.0, 0.0, 0.0, -12.0, -12.0],
    'Custom': [0.0, 0.0, 0.0, 0.0, 0.0],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initEqualizer();
    });
  }

  void _initEqualizer() {
    final storage = ref.read(storageServiceProvider);
    _activePreset = storage.getEqualizerPreset();
    final bands = storage.getEqualizerBands();
    _loadSliderValues(bands);
    setState(() {});
  }

  void _loadSliderValues(List<double> bands) {
    if (bands.length >= 5) {
      final avgBass = (bands[0] + bands[1]) / 2.0;
      final avgMid = (bands[2] + bands[3]) / 2.0;
      final treble = bands[4];

      _bassValue = ((avgBass / 24.0) + 0.5).clamp(0.0, 1.0);
      _midValue = ((avgMid / 24.0) + 0.5).clamp(0.0, 1.0);
      _trebleValue = ((treble / 24.0) + 0.5).clamp(0.0, 1.0);
    }
  }

  void _updateEqualizerBands(String channel, double sliderValue) {
    setState(() {
      if (channel == 'bass') {
        _bassValue = sliderValue;
      } else if (channel == 'mid') {
        _midValue = sliderValue;
      } else {
        _trebleValue = sliderValue;
      }
      _activePreset = 'Custom';
    });

    final bassDb = (_bassValue - 0.5) * 24.0;
    final midDb = (_midValue - 0.5) * 24.0;
    final trebleDb = (_trebleValue - 0.5) * 24.0;

    final updatedBands = [
      bassDb, // 60Hz
      bassDb * 0.8, // 230Hz
      midDb, // 1kHz
      midDb * 0.9, // 4kHz
      trebleDb, // 15kHz
    ];

    final storage = ref.read(storageServiceProvider);
    final playbackService = ref.read(playbackServiceProvider);

    storage.setEqualizerPreset('Custom');
    storage.setEqualizerBands(updatedBands);
    playbackService.setEqualizerBands(updatedBands);
  }

  void _selectPreset(String presetName) {
    final bands = _presets[presetName];
    if (bands != null) {
      setState(() {
        _activePreset = presetName;
        _loadSliderValues(bands);
      });

      final storage = ref.read(storageServiceProvider);
      final playbackService = ref.read(playbackServiceProvider);

      storage.setEqualizerPreset(presetName);
      storage.setEqualizerBands(bands);
      playbackService.setEqualizerBands(bands);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(playerSettingsProvider);
    final settingsNotifier = ref.read(playerSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ENGINE SETTINGS',
          style: theme.textTheme.displayMedium?.copyWith(
            color: AppColors.neonGreen,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomRight,
            radius: 1.4,
            colors: [
              Color(0xFF0C1622),
              AppColors.voidBlack,
            ],
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              16, 16, 16, kBottomNavigationBarHeight + 100),
          children: [
            // Theme Engine Section
            _buildSectionHeader('THEME ENGINE'),
            const SizedBox(height: 8),
            _buildToggleItem(
              title: 'Neon Glow Shadows',
              subtitle: 'Enable active accent lighting glows',
              value: settings.glowEnabled,
              onChanged: settingsNotifier.toggleGlowEnabled,
              activeColor: AppColors.neonGreen,
            ),
            _buildToggleItem(
              title: 'Glassmorphic Blurs',
              subtitle: 'Frosted dynamic backdrop filters',
              value: settings.glassEnabled,
              onChanged: settingsNotifier.toggleGlassEnabled,
              activeColor: AppColors.electricCyan,
            ),

            const SizedBox(height: 32),

            // Equalizer preset configuration
            _buildSectionHeader('GRAPHIC EQUALIZER (ACTIVE HARDWARE)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder, width: 0.8),
              ),
              child: Column(
                children: [
                  // Presets Dropdown Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ACTIVE PRESET',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          cardColor: AppColors.obsidianDark,
                        ),
                        child: PopupMenuButton<String>(
                          initialValue: _activePreset,
                          onSelected: _selectPreset,
                          itemBuilder: (BuildContext context) {
                            return _presets.keys.map((String key) {
                              return PopupMenuItem<String>(
                                value: key,
                                child: Text(
                                  key,
                                  style: TextStyle(
                                    color: key == _activePreset
                                        ? AppColors.neonGreen
                                        : AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: key == _activePreset
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.voidBlack,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.glassBorder, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _activePreset,
                                  style: const TextStyle(
                                      color: AppColors.neonGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_drop_down_rounded,
                                    color: AppColors.neonGreen, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sliding Dials Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEqualizerSlider('BASS (60Hz)', _bassValue,
                          (val) => _updateEqualizerBands('bass', val)),
                      _buildEqualizerSlider('MID (1kHz)', _midValue,
                          (val) => _updateEqualizerBands('mid', val)),
                      _buildEqualizerSlider('TREBLE (15kHz)', _trebleValue,
                          (val) => _updateEqualizerBands('treble', val)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Library Scanner Diagnostics
            _buildSectionHeader('OFFLINE INDEX DIAGNOSTICS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.glassBorder.withOpacity(0.04), width: 0.8),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final physicalSongs =
                      ref.watch(physicalSongsProvider).value ?? [];
                  final folders = physicalSongs
                      .map((s) =>
                          s.filePath.substring(0, s.filePath.lastIndexOf('/')))
                      .toSet();
                  return Column(
                    children: [
                      _DiagnosticRow(
                          label: 'Total Indexed Audio Files',
                          value: '${physicalSongs.length} songs'),
                      const Divider(
                          color: AppColors.glassBorder,
                          height: 16,
                          thickness: 0.5),
                      _DiagnosticRow(
                          label: 'Physical Folders Cataloged',
                          value: '${folders.length} folders'),
                      const Divider(
                          color: AppColors.glassBorder,
                          height: 16,
                          thickness: 0.5),
                      _DiagnosticRow(
                          label: 'Storage Caching Engine',
                          value: 'Hive v1.1.0 Local'),
                      const Divider(
                          color: AppColors.glassBorder,
                          height: 16,
                          thickness: 0.5),
                      _DiagnosticRow(
                          label: 'Metadata Extraction Core',
                          value: 'on_audio_query 3.0'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.glassBorder.withOpacity(0.04), width: 0.8),
      ),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
        subtitle: Text(subtitle,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        trailing: Switch(
          value: value,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEqualizerSlider(
      String label, double value, ValueChanged<double> onChanged) {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: RotatedBox(
            quarterTurns: 3,
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              activeColor: AppColors.electricCyan,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ],
    );
  }
}
