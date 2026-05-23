import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/core/theme/app_theme.dart';
import 'package:ultramp3/core/services/playback_service.dart';
import 'package:ultramp3/core/routing/routes.dart';
import '../../../../core/services/permission_service.dart';
import 'package:ultramp3/core/services/media_query_service.dart';
import 'package:ultramp3/features/playlists/presentation/providers/playlist_providers.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minStr = (duration.inMinutes).toString();
    final secStr = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  Future<void> _scanAndRefresh() async {
    // 1. Request permission
    final permissionService = ref.read(permissionServiceProvider);
    final granted = await permissionService.requestStoragePermission();
    
    if (granted) {
      // 2. Refresh provider
      ref.invalidate(physicalSongsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.obsidianDark,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.neonGreen, width: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          content: Text(
            'SCANNING DIRECTORIES...',
            style: GoogleFonts.shareTechMono(color: AppColors.neonGreen),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.obsidianDark,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.cyberPink, width: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          content: Text(
            'STORAGE ACCESS IS REQUIRED TO INDEX SONGS',
            style: GoogleFonts.shareTechMono(color: AppColors.cyberPink),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExtension = theme.extension<AppThemeExtension>()!;
    
    final songsAsync = ref.watch(physicalSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MEDIA LIBRARY',
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
              icon: const Icon(Icons.music_note_rounded, color: AppColors.neonGreen),
              onPressed: () => context.go('/library'),
            ),
            IconButton(
              tooltip: 'Folders',
              icon: const Icon(Icons.folder_rounded, color: AppColors.neonGreen),
              onPressed: () => context.go('/folders'),
            ),
            IconButton(
              tooltip: 'Playlists',
              icon: const Icon(Icons.queue_music_rounded, color: AppColors.neonGreen),
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
            icon: const Icon(Icons.refresh_rounded, color: AppColors.neonGreen),
            onPressed: _scanAndRefresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.electricCyan,
          labelColor: AppColors.electricCyan,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
          tabs: const [
            Tab(text: 'ALL SONGS'),
            Tab(text: 'ALBUMS'),
            Tab(text: 'ARTISTS'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.bottomCenter,
            radius: 1.5,
            colors: [
              Color(0xFF141424),
              AppColors.voidBlack,
            ],
          ),
        ),
        child: songsAsync.when(
          data: (songs) {
            if (songs.isEmpty) {
              return _buildEmptyState(context);
            }
            return TabBarView(
              controller: _tabController,
              children: [
                _buildSongsTab(songs, themeExtension),
                _buildAlbumsTab(songs, themeExtension),
                _buildArtistsTab(songs, themeExtension),
              ],
            );
          },
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.neonGreen),
                const SizedBox(height: 16),
                Text(
                  'SCANNING STORAGE DIRECTORIES...',
                  style: GoogleFonts.shareTechMono(
                    color: AppColors.neonGreen,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.cyberPink, size: 48),
                const SizedBox(height: 16),
                Text(
                  'ENGINE INDEXING EXCEPTION',
                  style: GoogleFonts.orbitron(color: AppColors.cyberPink, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  style: GoogleFonts.shareTechMono(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(physicalSongsProvider),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyberPink.withOpacity(0.1)),
                  child: const Text('RETRY SCAN', style: TextStyle(color: AppColors.cyberPink)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceCard.withOpacity(0.2),
                border: Border.all(color: AppColors.neonGreen.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonGreen.withOpacity(0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.music_off_rounded, color: AppColors.neonGreen, size: 54),
            ),
            const SizedBox(height: 32),
            Text(
              'COCKPIT LIBRARY VACANT',
              style: GoogleFonts.orbitron(
                color: AppColors.neonGreen,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No physical audio files found on device. Place MP3/WAV/FLAC tracks in your device\'s standard directories (e.g. Music, Downloads) and verify permissions.',
              style: GoogleFonts.shareTechMono(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _scanAndRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonGreen.withOpacity(0.15),
                foregroundColor: AppColors.neonGreen,
                side: const BorderSide(color: AppColors.neonGreen, width: 1.0),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                'TRIGGER DIRECTORY SCAN',
                style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsTab(List<AppTrack> songs, AppThemeExtension themeExtension) {
    final playbackService = ref.watch(playbackServiceProvider);
    final favList = ref.watch(favoritesProvider);

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavigationBarHeight + 100),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        final isFav = favList.contains(song.filePath);

        return Container(
          margin: const EdgeInsets.only(bottom: 10.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder.withOpacity(0.05), width: 0.8),
          ),
          child: ListTile(
            onTap: () async {
              await playbackService.playTrack(
                filePath: song.filePath,
                title: song.title,
                artist: song.artist,
                album: song.album,
                duration: song.duration,
                queue: songs.map((s) => s.filePath).toList(),
              );

              if (mounted) {
                GoRouter.of(context).go(AppRoutes.home);
              }
            },
            contentPadding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.voidBlack,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isFav ? AppColors.cyberPink.withOpacity(0.5) : AppColors.glassBorder, width: 0.8),
              ),
              child: Icon(
                isFav ? Icons.favorite_rounded : Icons.music_note, 
                color: isFav ? AppColors.cyberPink : AppColors.neonGreen, 
                size: 20,
              ),
            ),
            title: Text(
              song.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              song.artist,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(song.duration),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                  onPressed: () => _showTrackContextMenu(context, song, isFav),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumsTab(List<AppTrack> songs, AppThemeExtension themeExtension) {
    // Group songs by Album
    final Map<String, List<AppTrack>> albums = {};
    for (var song in songs) {
      albums.putIfAbsent(song.album, () => []).add(song);
    }

    final albumEntries = albums.entries.toList();

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavigationBarHeight + 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: albumEntries.length,
      itemBuilder: (context, index) {
        final albumName = albumEntries[index].key;
        final albumSongs = albumEntries[index].value;
        final artistName = albumSongs.first.artist;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showSongsListModal(context, 'ALBUM: $albumName', albumSongs),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.glassBorder.withOpacity(0.08), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.obsidianDark,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.album_rounded, 
                        color: AppColors.electricCyan.withOpacity(0.3),
                        size: 64,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        albumName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              artistName,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${albumSongs.length} trk',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtistsTab(List<AppTrack> songs, AppThemeExtension themeExtension) {
    // Group songs by Artist
    final Map<String, List<AppTrack>> artists = {};
    for (var song in songs) {
      artists.putIfAbsent(song.artist, () => []).add(song);
    }

    final artistEntries = artists.entries.toList();

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, kBottomNavigationBarHeight + 100),
      itemCount: artistEntries.length,
      itemBuilder: (context, index) {
        final artistName = artistEntries[index].key;
        final artistSongs = artistEntries[index].value;

        return Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder.withOpacity(0.05), width: 0.8),
          ),
          child: ListTile(
            onTap: () => _showSongsListModal(context, 'ARTIST: $artistName', artistSongs),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: AppColors.obsidianDark,
              child: Icon(Icons.person_rounded, color: AppColors.neonGreen.withOpacity(0.7), size: 20),
            ),
            title: Text(
              artistName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${artistSongs.length} songs',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
          ),
        );
      },
    );
  }

  void _showTrackContextMenu(BuildContext context, AppTrack song, bool isFav) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.obsidianDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.neonGreen, width: 1.5)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.voidBlack,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.music_note, color: AppColors.neonGreen),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              song.artist,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.glassBorder, height: 1),
                ListTile(
                  leading: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                    color: AppColors.cyberPink,
                  ),
                  title: Text(
                    isFav ? 'REMOVE FROM FAVORITES' : 'ADD TO FAVORITES',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onTap: () {
                    ref.read(favoritesProvider.notifier).toggle(song.filePath);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded, color: AppColors.electricCyan),
                  title: const Text(
                    'ADD TO PLAYLIST',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddToPlaylistDialog(song);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistDialog(AppTrack song) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final playlists = ref.watch(playlistsProvider);

            return AlertDialog(
              backgroundColor: AppColors.obsidianDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
              ),
              title: Text(
                'CHOOSE PLAYLIST',
                style: GoogleFonts.orbitron(
                  color: AppColors.neonGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 200,
                child: playlists.isEmpty
                    ? Center(
                        child: Text(
                          'NO CUSTOM PLAYLISTS DETECTED',
                          style: GoogleFonts.shareTechMono(color: AppColors.textMuted, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        itemCount: playlists.length,
                        itemBuilder: (context, index) {
                          final pName = playlists.keys.elementAt(index);
                          return ListTile(
                            leading: const Icon(Icons.playlist_play_rounded, color: AppColors.neonGreen),
                            title: Text(pName, style: const TextStyle(color: AppColors.textPrimary)),
                            onTap: () {
                              ref.read(playlistsProvider.notifier).addSongToPlaylist(pName, song.filePath);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.obsidianDark,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(color: AppColors.neonGreen, width: 0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  content: Text(
                                    'ADDED TO PLAYLIST: $pName',
                                    style: GoogleFonts.shareTechMono(color: AppColors.neonGreen),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  child: const Text('CLOSE', style: TextStyle(color: AppColors.textMuted)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSongsListModal(BuildContext context, String title, List<AppTrack> songs) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Consumer(
            builder: (context, ref, child) {
              final playbackService = ref.watch(playbackServiceProvider);
              return Scaffold(
                backgroundColor: AppColors.obsidianDark,
                appBar: AppBar(
                  backgroundColor: AppColors.obsidianDark,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
                          '${songs.length} TRACKS',
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
                    if (songs.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                label: const Text('PLAY ALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neonGreen.withOpacity(0.12),
                                  foregroundColor: AppColors.neonGreen,
                                  side: const BorderSide(color: AppColors.neonGreen, width: 1.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final player = playbackService.handler.playerInstance;
                                  await player.setShuffleModeEnabled(false);
                                  await playbackService.playTrack(
                                    filePath: songs.first.filePath,
                                    title: songs.first.title,
                                    artist: songs.first.artist,
                                    album: songs.first.album,
                                    duration: songs.first.duration,
                                    queue: songs.map((t) => t.filePath).toList(),
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
                                icon: const Icon(Icons.shuffle_rounded, size: 18),
                                label: const Text('SHUFFLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.electricCyan.withOpacity(0.12),
                                  foregroundColor: AppColors.electricCyan,
                                  side: const BorderSide(color: AppColors.electricCyan, width: 1.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final player = playbackService.handler.playerInstance;
                                  final shuffled = List<AppTrack>.from(songs)..shuffle();
                                  await player.setShuffleModeEnabled(true);
                                  await playbackService.playTrack(
                                    filePath: shuffled.first.filePath,
                                    title: shuffled.first.title,
                                    artist: shuffled.first.artist,
                                    album: shuffled.first.album,
                                    duration: shuffled.first.duration,
                                    queue: shuffled.map((t) => t.filePath).toList(),
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
                      child: songs.isEmpty
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
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
                              itemCount: songs.length,
                              itemBuilder: (context, index) {
                                final track = songs[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: AppColors.surfaceCard.withOpacity(0.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: AppColors.glassBorder.withOpacity(0.05),
                                      width: 0.8,
                                    ),
                                  ),
                                  elevation: 0,
                                  clipBehavior: Clip.antiAlias,
                                  child: ListTile(
                                    onTap: () async {
                                      await playbackService.playTrack(
                                        filePath: track.filePath,
                                        title: track.title,
                                        artist: track.artist,
                                        album: track.album,
                                        duration: track.duration,
                                        queue: songs.map((t) => t.filePath).toList(),
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        GoRouter.of(context).go(AppRoutes.home);
                                      }
                                    },
                                    leading: const Icon(Icons.music_note, color: AppColors.neonGreen, size: 20),
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
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.electricCyan, size: 18),
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
