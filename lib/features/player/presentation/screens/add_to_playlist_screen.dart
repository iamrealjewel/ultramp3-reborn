import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/features/playlists/presentation/providers/playlist_providers.dart';

class AddToPlaylistScreen extends ConsumerStatefulWidget {
  final String songId;
  final String songTitle;

  const AddToPlaylistScreen({
    super.key,
    required this.songId,
    required this.songTitle,
  });

  @override
  ConsumerState<AddToPlaylistScreen> createState() => _AddToPlaylistScreenState();
}

class _AddToPlaylistScreenState extends ConsumerState<AddToPlaylistScreen> {
  final _playlistNameController = TextEditingController();

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog(BuildContext screenContext) {
    _playlistNameController.clear();
    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A), width: 1.5),
        ),
        title: const Text(
          'NEW PLAYLIST',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Orbitron',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        content: TextField(
          controller: _playlistNameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter playlist name...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF09090B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.cyberPink, width: 1.5),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.only(bottom: 12, right: 16, left: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Orbitron'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _playlistNameController.text.trim();
              if (name.isNotEmpty) {
                // Create playlist and add song to it
                await ref.read(playlistsProvider.notifier).createPlaylist(name);
                await ref.read(playlistsProvider.notifier).addSongToPlaylist(name, widget.songId);
                // Close dialog first using dialog's own context
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                // Then close AddToPlaylistScreen using the screen's context
                if (mounted && screenContext.mounted) {
                  _showToast(screenContext, 'ADDED TO ${name.toUpperCase()}');
                  Navigator.of(screenContext).pop();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyberPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'CREATE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            message.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF1E1E24),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.cyberPink, width: 1.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistsMap = ref.watch(playlistsProvider);
    final playlistNames = playlistsMap.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar replacement
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF18181B), width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ADD TO PLAYLIST',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_box_rounded, color: AppColors.cyberPink, size: 26),
                    tooltip: 'Create New Playlist',
                    onPressed: () => _showCreatePlaylistDialog(context),
                  ),
                ],
              ),
            ),

            // Track summary card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF27272A), width: 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF09090B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cyberPink.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: AppColors.cyberPink, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SELECTED SONG',
                          style: TextStyle(
                            color: Colors.white38,
                            fontFamily: 'Orbitron',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.songTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Playlists List
            Expanded(
              child: playlistNames.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.playlist_add_rounded, color: Colors.white.withOpacity(0.2), size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'NO PLAYLISTS YET',
                            style: TextStyle(
                              color: Colors.white30,
                              fontFamily: 'Orbitron',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showCreatePlaylistDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'CREATE PLAYLIST',
                              style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyberPink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: playlistNames.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final name = playlistNames[index];
                        final songCount = playlistsMap[name]?.length ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121214),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1F1F23), width: 1.0),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF18181B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.playlist_play_rounded, color: Colors.white70, size: 24),
                            ),
                            title: Text(
                              name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Orbitron',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            subtitle: Text(
                              '$songCount SONGS',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                            onTap: () async {
                              await ref.read(playlistsProvider.notifier).addSongToPlaylist(name, widget.songId);
                              if (context.mounted) {
                                _showToast(context, 'ADDED TO $name');
                                Navigator.pop(context);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
