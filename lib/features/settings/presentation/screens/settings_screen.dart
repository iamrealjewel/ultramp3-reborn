import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/features/player/presentation/providers/player_settings_provider.dart';
import 'package:ultramp3/core/services/media_query_service.dart';
import 'package:ultramp3/core/services/playback_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(playerSettingsProvider);
    final settingsNotifier = ref.read(playerSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.voidBlack,
      appBar: AppBar(
        backgroundColor: AppColors.voidBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
          padding: const EdgeInsets.all(16),
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

            // Playback Engine Section
            _buildSectionHeader('PLAYBACK DECODER ENGINE'),
            const SizedBox(height: 8),
            _buildEngineSelectorItem(
              title: 'Active Audio Engine',
              subtitle: 'Select underlying decoders and DSP',
              currentValue: settings.audioEngine,
              activeColor: AppColors.neonGreen,
              onChanged: (newEngine) async {
                if (newEngine == settings.audioEngine) return;
                
                final playbackService = ref.read(playbackServiceProvider);
                final currentTrack = playbackService.handler.mediaItem.valueOrNull;
                final currentPosition = playbackService.handler.playerInstance.position;
                
                settingsNotifier.setAudioEngine(newEngine);
                playbackService.handler.updateEngineSelection(newEngine);
                
                if (currentTrack != null) {
                  await playbackService.playTrack(
                    filePath: currentTrack.id,
                    title: currentTrack.title,
                    artist: currentTrack.artist ?? 'Unknown Artist',
                    album: currentTrack.album ?? 'Unknown Album',
                    duration: currentTrack.duration ?? Duration.zero,
                  );
                  if (currentPosition > Duration.zero) {
                    await playbackService.seek(currentPosition);
                  }
                }
              },
            ),

            const SizedBox(height: 32),

            // Library Scanner Diagnostics
            _buildSectionHeader('OFFLINE INDEX DIAGNOSTICS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.glassBorder.withValues(alpha: 0.04), width: 0.8),
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
        color: AppColors.surfaceCard.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.04), width: 0.8),
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

  Widget _buildEngineSelectorItem({
    required String title,
    required String subtitle,
    required String currentValue,
    required ValueChanged<String> onChanged,
    required Color activeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.glassBorder.withValues(alpha: 0.04), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSegmentButton(
                  label: 'SoLoud C++ Engine',
                  isActive: currentValue == 'soloud',
                  onTap: () => onChanged('soloud'),
                  activeColor: activeColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSegmentButton(
                  label: 'JustAudio Native SDK',
                  isActive: currentValue == 'just_audio',
                  onTap: () => onChanged('just_audio'),
                  activeColor: activeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.01),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? activeColor
                : Colors.white.withValues(alpha: 0.08),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white38,
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
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
