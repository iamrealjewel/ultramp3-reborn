import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ultramp3/core/theme/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _glowEnabled = true;
  bool _glassEnabled = true;
  double _bassValue = 0.6;
  double _midValue = 0.45;
  double _trebleValue = 0.7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavigationBarHeight + 100),
          children: [
            // Theme Engine Section
            _buildSectionHeader('THEME ENGINE'),
            const SizedBox(height: 8),
            _buildToggleItem(
              title: 'Neon Glow Shadows',
              subtitle: 'Enable active accent lighting glows',
              value: _glowEnabled,
              onChanged: (val) => setState(() => _glowEnabled = val),
              activeColor: AppColors.neonGreen,
            ),
            _buildToggleItem(
              title: 'Glassmorphic Blurs',
              subtitle: 'Frosted dynamic backdrop filters',
              value: _glassEnabled,
              onChanged: (val) => setState(() => _glassEnabled = val),
              activeColor: AppColors.electricCyan,
            ),

            const SizedBox(height: 32),

            // Equalizer Placeholder UI
            _buildSectionHeader('GRAPHIC EQUALIZER (PRESET ARCHITECTURE)'),
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
                  // Presets Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ACTIVE PRESET',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.voidBlack,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorder, width: 0.8),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'Retro Synthwave',
                              style: TextStyle(color: AppColors.neonGreen, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Icon(Icons.arrow_drop_down_rounded, color: AppColors.neonGreen, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Sliding Dials Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEqualizerSlider('BASS (60Hz)', _bassValue, (val) => setState(() => _bassValue = val)),
                      _buildEqualizerSlider('MID (1kHz)', _midValue, (val) => setState(() => _midValue = val)),
                      _buildEqualizerSlider('TREBLE (15kHz)', _trebleValue, (val) => setState(() => _trebleValue = val)),
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
                border: Border.all(color: AppColors.glassBorder.withOpacity(0.04), width: 0.8),
              ),
              child: const Column(
                children: [
                  _DiagnosticRow(label: 'Total Indexed Audio Files', value: '142 songs'),
                  Divider(color: AppColors.glassBorder, height: 16, thickness: 0.5),
                  _DiagnosticRow(label: 'Physical Folders Cataloged', value: '4 folders'),
                  Divider(color: AppColors.glassBorder, height: 16, thickness: 0.5),
                  _DiagnosticRow(label: 'Storage Caching Engine', value: 'Hive v1.1.0 Local'),
                  Divider(color: AppColors.glassBorder, height: 16, thickness: 0.5),
                  _DiagnosticRow(label: 'Metadata Extraction Core', value: 'on_audio_query 3.0'),
                ],
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
        border: Border.all(color: AppColors.glassBorder.withOpacity(0.04), width: 0.8),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        trailing: Switch(
          value: value,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEqualizerSlider(String label, double value, ValueChanged<double> onChanged) {
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
