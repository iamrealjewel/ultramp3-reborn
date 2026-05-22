import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/services/playback_service.dart';
import '../providers/player_skin_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackService = ref.watch(playbackServiceProvider);
    final activeSkin = ref.watch(playerSkinProvider);

    return StreamBuilder<MediaItem?>(
      stream: playbackService.currentMediaItemStream,
      builder: (context, mediaSnapshot) {
        final mediaItem = mediaSnapshot.data;
        
        // Hide MiniPlayer completely if no audio is loaded/active
        if (mediaItem == null) {
          return const SizedBox.shrink();
        }

        final String trackTitle = mediaItem.title;
        final String trackArtist = mediaItem.artist ?? 'Unknown Artist';

        return GestureDetector(
          onTap: () => GoRouter.of(context).go(AppRoutes.home),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.obsidianDark.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: activeSkin.textColor.withOpacity(0.15), width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: activeSkin.textColor.withOpacity(0.08),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Stack(
                  children: [
                    // Layout
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          // Rotating Vinyl Disc (skinned color outline)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.voidBlack,
                              border: Border.all(color: activeSkin.textColor, width: 1.5),
                              boxShadow: [
                                BoxShadow(color: activeSkin.textColor.withOpacity(0.3), blurRadius: 4),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.album_rounded, color: Colors.white24, size: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Song Info (Title & Artist)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  trackTitle.toUpperCase(),
                                  style: TextStyle(
                                    color: activeSkin.textColor,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(color: activeSkin.textColor.withOpacity(0.2), blurRadius: 4),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  trackArtist,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          
                          // Control actions
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, color: AppColors.textPrimary, size: 24),
                            onPressed: () => playbackService.skipToPrevious(),
                          ),
                          
                          StreamBuilder<PlaybackState>(
                            stream: playbackService.playbackStateStream,
                            builder: (context, stateSnapshot) {
                              final isPlaying = stateSnapshot.data?.playing ?? false;
                              return Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: activeSkin.textColor.withOpacity(0.1),
                                  border: Border.all(color: activeSkin.textColor, width: 1.0),
                                ),
                                child: Center(
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, 
                                      color: activeSkin.textColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      if (isPlaying) {
                                        playbackService.pause();
                                      } else {
                                        playbackService.play();
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, color: AppColors.textPrimary, size: 24),
                            onPressed: () => playbackService.skipToNext(),
                          ),
                        ],
                      ),
                    ),
                    
                    // Micro timeline progress line
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: StreamBuilder<PositionState>(
                        stream: playbackService.positionStateStream,
                        builder: (context, posSnapshot) {
                          final posData = posSnapshot.data;
                          final position = posData?.position ?? Duration.zero;
                          final duration = posData?.duration ?? Duration.zero;
                          double progressFactor = 0.0;
                          
                          if (duration.inMilliseconds > 0) {
                            progressFactor = position.inMilliseconds / duration.inMilliseconds;
                          }

                          return Container(
                            height: 2.2,
                            width: double.infinity,
                            color: Colors.white.withOpacity(0.05),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progressFactor.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: activeSkin.textColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: activeSkin.textColor,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
