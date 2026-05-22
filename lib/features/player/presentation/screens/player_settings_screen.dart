import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_settings_provider.dart';
import '../providers/player_skin_provider.dart';

class PlayerSettingsScreen extends ConsumerWidget {
  const PlayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(playerSettingsProvider);
    final settingsNotifier = ref.read(playerSettingsProvider.notifier);

    // Premium solid dark charcoal background
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: [
            // Frosted static custom AppBar
            _buildAppBar(context),

            // Settings List
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Section 1: Skin Architecture
                  _buildSettingsCard(
                    title: 'SKIN ARCHITECTURE',
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSegmentButton(
                              label: 'CLASSIC SKEUOMORPHIC',
                              isActive: settings.skinType == 'classic',
                              onTap: () {
                                settingsNotifier.setSkinType('classic');
                                ref.read(playerSkinProvider.notifier).enforceSkinType('classic');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSegmentButton(
                              label: 'FLAT MINIMAL',
                              isActive: settings.skinType == 'flat',
                              onTap: () {
                                settingsNotifier.setSkinType('flat');
                                ref.read(playerSkinProvider.notifier).enforceSkinType('flat');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),

                  if (settings.skinType != 'flat') ...[
                    // Section 2: Dialer Controls
                    _buildSettingsCard(
                      title: 'DIALER CONSOLE OPTIONS',
                      children: [
                        _buildToggleRow(
                          label: 'Enable Dialer Transparency',
                          value: settings.dialerTransparencyEnabled,
                          onChanged: settingsNotifier.toggleDialerTransparency,
                        ),
                        if (settings.dialerTransparencyEnabled) ...[
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Opacity Level',
                            value: settings.dialerOpacity,
                            min: 0.15,
                            max: 1.0,
                            onChanged: settingsNotifier.setDialerOpacity,
                            displayValue: '${(settings.dialerOpacity * 100).toInt()}%',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Section 3: Visualizer & Viewport settings
                  _buildSettingsCard(
                    title: 'VISUALIZER / COCKPIT CORES',
                    children: [
                      _buildToggleRow(
                        label: 'Show Album Art (instead of Visualizer)',
                        value: settings.showAlbumArt,
                        onChanged: settingsNotifier.toggleShowAlbumArt,
                      ),
                      if (settings.skinType != 'flat') ...[
                        const Divider(color: Colors.white10, height: 24, thickness: 0.8),
                        _buildToggleRow(
                          label: 'Enable Visualizer Transparency',
                          value: settings.visualizerTransparencyEnabled,
                          onChanged: settingsNotifier.toggleVisualizerTransparency,
                        ),
                        if (settings.visualizerTransparencyEnabled) ...[
                          const SizedBox(height: 12),
                          _buildSliderRow(
                            label: 'Backdrop Opacity',
                            value: settings.visualizerOpacity,
                            min: 0.0,
                            max: 1.0,
                            onChanged: settingsNotifier.setVisualizerOpacity,
                            displayValue: '${(settings.visualizerOpacity * 100).toInt()}%',
                          ),
                        ],
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            'PLAYER CONFIG',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: Colors.white.withOpacity(0.15),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive 
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.01),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive 
                ? Colors.white.withOpacity(0.6)
                : Colors.white.withOpacity(0.08),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 10,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          activeColor: Colors.white,
          activeTrackColor: Colors.white24,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required String displayValue,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 2,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
