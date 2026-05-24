import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/playback_service.dart';
import '../../../../core/routing/routes.dart';
import 'dart:io';
import '../../../../core/services/media_query_service.dart';
import '../providers/playlist_providers.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExtension = theme.extension<AppThemeExtension>()!;

    final playlists = ref.watch(playlistsProvider);
    final favorites = ref.watch(favoritesProvider);
    final recentlyPlayed = ref.watch(recentlyPlayedProvider);
    final physicalSongsAsync = ref.watch(physicalSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PLAYLIST ENGINE',
          style: theme.textTheme.displayMedium?.copyWith(
            color: AppColors.neonGreen,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          if (MediaQuery.of(context).orientation == Orientation.landscape) ...[
            IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.home_rounded, color: AppColors.neonGreen),
              onPressed: () => context.go('/home'),
            ),
            IconButton(
              tooltip: 'Library',
              icon: const Icon(Icons.music_note_rounded,
                  color: AppColors.neonGreen),
              onPressed: () => context.go('/library'),
            ),
            IconButton(
              tooltip: 'Folders',
              icon:
                  const Icon(Icons.folder_rounded, color: AppColors.neonGreen),
              onPressed: () => context.go('/folders'),
            ),
            IconButton(
              tooltip: 'Playlists',
              icon: const Icon(Icons.queue_music_rounded,
                  color: AppColors.neonGreen),
              onPressed: () => context.go('/playlists'),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 16,
              color: AppColors.neonGreen.withOpacity(0.2),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.add_box_rounded, color: AppColors.neonGreen),
            onPressed: () => _showCreatePlaylistDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.3,
            colors: [
              Color(0xFF140F24),
              AppColors.voidBlack,
            ],
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
              16, 16, 16, kBottomNavigationBarHeight + 100),
          children: [
            // Core Nodes (Favorites & Recents Grid)
            Row(
              children: [
                Expanded(
                  child: _buildCoreCard(
                    context: context,
                    icon: Icons.favorite_rounded,
                    title: 'Favorites',
                    count: '${favorites.length} Songs',
                    color: AppColors.cyberPink,
                    glow: themeExtension.pinkGlow,
                    onTap: () => _showPlaylistSongs(
                        context, 'Favorites', favorites,
                        isFavoritesTab: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCoreCard(
                    context: context,
                    icon: Icons.history_rounded,
                    title: 'Recently Played',
                    count: '${recentlyPlayed.length} Songs',
                    color: AppColors.electricCyan,
                    glow: themeExtension.cyanGlow,
                    onTap: () => _showPlaylistSongs(
                        context, 'Recently Played', recentlyPlayed),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Secondary Nodes (Recently Added & Most Played)
            Builder(builder: (context) {
              final physicalSongs = physicalSongsAsync.value ?? [];

              // Smart playlist logic
              // Recently Added: take newest files (simulated by taking first 20)
              final recentlyAddedIds =
                  physicalSongs.take(20).map((s) => s.id).toList();

              // Most Played: Use recentlyPlayed data, fallback to arbitrary slice
              final mostPlayedIds = recentlyPlayed.isNotEmpty
                  ? recentlyPlayed
                  : physicalSongs.reversed.take(15).map((s) => s.id).toList();

              return Row(
                children: [
                  Expanded(
                    child: _buildCoreCard(
                      context: context,
                      icon: Icons.new_releases_rounded,
                      title: 'Recently Added',
                      count: '${recentlyAddedIds.length} Songs',
                      color: const Color(0xFFFFB300),
                      glow: themeExtension.greenGlow, // using existing glow
                      onTap: () => _showPlaylistSongs(
                          context, 'Recently Added', recentlyAddedIds),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildCoreCard(
                      context: context,
                      icon: Icons.trending_up_rounded,
                      title: 'Most Played',
                      count: '${mostPlayedIds.length} Songs',
                      color: AppColors.laserViolet,
                      glow: themeExtension.pinkGlow, // using existing glow
                      onTap: () => _showPlaylistSongs(
                          context, 'Most Played', mostPlayedIds),
                    ),
                  ),
                ],
              );
            }),

            const SizedBox(height: 32),

            // Custom Playlists Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'YOUR OFFLINE PLAYLISTS',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '${playlists.length} Folders',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Playlists vertical builder
            if (playlists.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                child: Text(
                  'NO CUSTOM PLAYLISTS\nTAP + TO BUILD ONE',
                  style: GoogleFonts.shareTechMono(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...playlists.entries
                  .map((entry) => _buildPlaylistItem(entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String count,
    required Color color,
    required List<BoxShadow> glow,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.surfaceCard.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.0),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Glowing Circle Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.voidBlack,
                  border: Border.all(color: color, width: 1.5),
                  boxShadow: glow,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistItem(String name, List<String> songIds) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10.0),
      color: AppColors.surfaceCard.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: AppColors.glassBorder.withOpacity(0.05), width: 0.8),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _showPlaylistSongs(context, name, songIds),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.obsidianDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
          ),
          child: const Icon(Icons.playlist_play_rounded,
              color: AppColors.neonGreen, size: 24),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: const Text(
          'Offline User Playlist',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${songIds.length} Tracks',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.textMuted, size: 20),
              onPressed: () {
                ref.read(playlistsProvider.notifier).deletePlaylist(name);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.obsidianDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
          ),
          title: const Text(
            'NEW PLAYLIST',
            style: TextStyle(
                color: AppColors.neonGreen,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.0),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter playlist title...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.glassBorder.withOpacity(0.5)),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.electricCyan),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('CANCEL',
                  style: TextStyle(color: AppColors.textMuted)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen.withOpacity(0.1),
                foregroundColor: AppColors.neonGreen,
                side: const BorderSide(color: AppColors.neonGreen, width: 0.8),
              ),
              child: const Text('CREATE'),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  ref
                      .read(playlistsProvider.notifier)
                      .createPlaylist(controller.text.trim());
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showPlaylistSongs(
      BuildContext context, String title, List<String> songIds,
      {bool isFavoritesTab = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Consumer(
            builder: (context, ref, child) {
              // Re-fetch inside in case of updates
              final allSongs = ref.watch(physicalSongsProvider).value ?? [];
              final playlistsState = ref.watch(playlistsProvider);
              final favoritesState = ref.watch(favoritesProvider);

              final activeIds = isFavoritesTab
                  ? favoritesState
                  : (title == 'Recently Played'
                      ? ref.watch(recentlyPlayedProvider)
                      : (title == 'Recently Added' || title == 'Most Played'
                          ? songIds
                          : (playlistsState[title] ?? [])));

              final List<AppTrack> matchingTracks = [];
              for (var id in activeIds) {
                final track = allSongs.firstWhere((t) => t.id == id,
                    orElse: () => AppTrack(
                          id: id,
                          title: id
                              .split(Platform.pathSeparator)
                              .last
                              .toUpperCase(),
                          artist: 'Unknown Artist',
                          album: 'Unknown Album',
                          filePath: id,
                          duration: Duration.zero,
                          size: 0,
                        ));
                matchingTracks.add(track);
              }

              final playbackService = ref.watch(playbackServiceProvider);

              return Scaffold(
                backgroundColor: AppColors.obsidianDark,
                appBar: AppBar(
                  backgroundColor: AppColors.obsidianDark,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    title.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      color: AppColors.neonGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  actions: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Text(
                          '${matchingTracks.length} TRACKS',
                          style: GoogleFonts.shareTechMono(
                            color: AppColors.electricCyan,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(
                      color: AppColors.glassBorder.withOpacity(0.2),
                      height: 1,
                    ),
                  ),
                ),
                body: Column(
                  children: [
                    if (matchingTracks.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded,
                                    size: 18),
                                label: const Text('PLAY ALL',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.neonGreen.withOpacity(0.12),
                                  foregroundColor: AppColors.neonGreen,
                                  side: const BorderSide(
                                      color: AppColors.neonGreen, width: 1.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final player =
                                      playbackService.handler.playerInstance;
                                  await player.setShuffleModeEnabled(false);
                                  await playbackService.playTrack(
                                    filePath: matchingTracks.first.filePath,
                                    title: matchingTracks.first.title,
                                    artist: matchingTracks.first.artist,
                                    album: matchingTracks.first.album,
                                    duration: matchingTracks.first.duration,
                                    queue: matchingTracks
                                        .map((t) => t.filePath)
                                        .toList(),
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    GoRouter.of(context).go(AppRoutes.home);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon:
                                    const Icon(Icons.shuffle_rounded, size: 18),
                                label: const Text('SHUFFLE',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      AppColors.electricCyan.withOpacity(0.12),
                                  foregroundColor: AppColors.electricCyan,
                                  side: const BorderSide(
                                      color: AppColors.electricCyan,
                                      width: 1.0),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final player =
                                      playbackService.handler.playerInstance;
                                  final shuffled =
                                      List<AppTrack>.from(matchingTracks)
                                        ..shuffle();
                                  await player.setShuffleModeEnabled(true);
                                  await playbackService.playTrack(
                                    filePath: shuffled.first.filePath,
                                    title: shuffled.first.title,
                                    artist: shuffled.first.artist,
                                    album: shuffled.first.album,
                                    duration: shuffled.first.duration,
                                    queue: shuffled
                                        .map((t) => t.filePath)
                                        .toList(),
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    GoRouter.of(context).go(AppRoutes.home);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(color: AppColors.glassBorder, height: 24),
                    Expanded(
                      child: matchingTracks.isEmpty
                          ? Center(
                              child: Text(
                                'NO TRACKS CONFIGURED',
                                style: GoogleFonts.shareTechMono(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, bottom: 40),
                              itemCount: matchingTracks.length,
                              itemBuilder: (context, index) {
                                final track = matchingTracks[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: AppColors.surfaceCard.withOpacity(0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: AppColors.glassBorder
                                          .withOpacity(0.05),
                                      width: 0.8,
                                    ),
                                  ),
                                  elevation: 0,
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    onTap: () async {
                                      // Play song
                                      await playbackService.playTrack(
                                        filePath: track.filePath,
                                        title: track.title,
                                        artist: track.artist,
                                        album: track.album,
                                        duration: track.duration,
                                        queue: matchingTracks
                                            .map((t) => t.filePath)
                                            .toList(),
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        GoRouter.of(context).go(AppRoutes.home);
                                      }
                                    },
                                    leading: const Icon(Icons.music_note,
                                        color: AppColors.neonGreen, size: 20),
                                    title: Text(
                                      track.title,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      track.artist,
                                      style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          color: AppColors.cyberPink, size: 18),
                                      onPressed: () async {
                                        if (isFavoritesTab) {
                                          await ref
                                              .read(favoritesProvider.notifier)
                                              .toggle(track.filePath);
                                        } else if (title != 'Recently Played') {
                                          await ref
                                              .read(playlistsProvider.notifier)
                                              .removeSongFromPlaylist(
                                                  title, track.filePath);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
