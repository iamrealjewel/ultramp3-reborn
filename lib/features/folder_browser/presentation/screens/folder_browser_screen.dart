import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/core/theme/app_theme.dart';
import '../../../../core/services/playback_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/routing/routes.dart';
import 'package:ultramp3/core/services/media_query_service.dart';

class FolderBrowserScreen extends ConsumerStatefulWidget {
  const FolderBrowserScreen({super.key});

  @override
  ConsumerState<FolderBrowserScreen> createState() =>
      _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  String _currentPath = '/';
  bool _hasPermission = true;
  bool _isLoading = false;
  String? _error;
  List<FileSystemEntity> _entities = [];

  @override
  void initState() {
    super.initState();
    _initDirectory();
  }

  Future<void> _initDirectory() async {
    final permissionService = ref.read(permissionServiceProvider);
    final hasPerm = await permissionService.hasStoragePermission();
    if (!hasPerm) {
      setState(() {
        _hasPermission = false;
      });
      return;
    }

    Directory? initialDir;
    try {
      if (Platform.isAndroid) {
        initialDir = Directory('/storage/emulated/0');
        if (!await initialDir.exists()) {
          initialDir = await getExternalStorageDirectory();
        }
      } else {
        initialDir = await getMusicDirectoryFallback();
      }
    } catch (e) {
      print('Initial directory discovery error: $e');
    }

    setState(() {
      _currentPath = initialDir?.path ?? '/';
      _hasPermission = true;
    });

    await _loadDirectoryContents();
  }

  Future<void> _loadDirectoryContents() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _entities = [];
    });

    try {
      final dir = Directory(_currentPath);
      if (await dir.exists()) {
        final List<FileSystemEntity> list = [];
        await for (final entity in dir.list(followLinks: false)) {
          final name = p.basename(entity.path);
          if (name.startsWith('.')) continue; // skip hidden files/folders

          if (entity is Directory) {
            list.add(entity);
          } else if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (ext == '.mp3' ||
                ext == '.wav' ||
                ext == '.flac' ||
                ext == '.m4a' ||
                ext == '.ogg') {
              list.add(entity);
            }
          }
        }

        // Sort folders first, then files alphabetically
        list.sort((a, b) {
          if (a is Directory && b is! Directory) return -1;
          if (a is! Directory && b is Directory) return 1;
          return p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase());
        });

        setState(() {
          _entities = list;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'DIRECTORY NOT FOUND';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'ERROR LISTING DIRECTORY:\n$e';
        _isLoading = false;
      });
    }
  }

  void _navigateUp() {
    final parent = Directory(_currentPath).parent;
    if (parent.path != _currentPath) {
      setState(() {
        _currentPath = parent.path;
      });
      _loadDirectoryContents();
    }
  }

  Future<void> _playFolder() async {
    final files = _entities.whereType<File>().toList();
    if (files.isNotEmpty) {
      final first = files.first;
      final title = p.basenameWithoutExtension(first.path).toUpperCase();
      final parentDirName =
          p.basename(Directory(first.path).parent.path).toUpperCase();

      final playbackService = ref.read(playbackServiceProvider);

      // 1. Play the first track
      await playbackService.playTrack(
        filePath: first.path,
        title: title,
        artist: 'FOLDER AUDIO',
        album: parentDirName,
        duration: const Duration(seconds: 240),
      );

      // 2. Feed all files as the active queue to storage
      final filePaths = files.map((f) => f.path).toList();
      await ref.read(storageServiceProvider).saveQueueState(
            songIds: filePaths,
            activeSongId: first.path,
            playbackPositionMs: 0,
          );

      if (mounted) {
        GoRouter.of(context).go(AppRoutes.home);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.obsidianDark,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.cyberPink, width: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          content: Text(
            'NO PLAYABLE AUDIO DETECTED IN THIS DIR',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'FOLDER BROWSER',
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
            icon: const Icon(Icons.refresh_rounded, color: AppColors.neonGreen),
            onPressed: _loadDirectoryContents,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF161226),
              AppColors.voidBlack,
            ],
          ),
        ),
        child: _hasPermission
            ? _buildBrowserBody(theme, themeExtension)
            : _buildPermissionDeniedBody(theme),
      ),
    );
  }

  Widget _buildBrowserBody(ThemeData theme, AppThemeExtension themeExtension) {
    return Column(
      children: [
        // Path indicator & Play Folder bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          color: AppColors.obsidianDark.withOpacity(0.8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT PATH',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentPath,
                      style: const TextStyle(
                        color: AppColors.electricCyan,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Action: Play Folder
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen.withOpacity(0.1),
                  foregroundColor: AppColors.neonGreen,
                  shadowColor: Colors.transparent,
                  side:
                      const BorderSide(color: AppColors.neonGreen, width: 0.8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                label: const Text('Play Folder',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _playFolder,
              ),
            ],
          ),
        ),

        // Loader / Error / Content
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                          color: AppColors.electricCyan),
                      const SizedBox(height: 16),
                      Text(
                        'OPENING STORAGE NODE...',
                        style: GoogleFonts.shareTechMono(
                            color: AppColors.electricCyan),
                      ),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.cyberPink, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'ACCESS BLOCK DETECTED',
                              style: GoogleFonts.orbitron(
                                  color: AppColors.cyberPink,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: GoogleFonts.shareTechMono(
                                  color: AppColors.textSecondary, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _navigateUp,
                              icon: const Icon(Icons.arrow_upward_rounded),
                              label: const Text('GO UP A LEVEL'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppColors.cyberPink.withOpacity(0.1),
                                foregroundColor: AppColors.cyberPink,
                                side: const BorderSide(
                                    color: AppColors.cyberPink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                          16, 12, 16, kBottomNavigationBarHeight + 100),
                      itemCount: _entities.length +
                          1, // +1 for the Parent Directory '..'
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            color: AppColors.surfaceCard.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                  color:
                                      AppColors.glassBorder.withOpacity(0.04),
                                  width: 0.8),
                            ),
                            elevation: 0,
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.voidBlack.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: AppColors.electricCyan,
                                  size: 18,
                                ),
                              ),
                              title: const Text(
                                '.. (Parent Directory)',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onTap: _navigateUp,
                            ),
                          );
                        }

                        final entity = _entities[index - 1];
                        final isDir = entity is Directory;
                        final name = p.basename(entity.path);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          color: AppColors.surfaceCard.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: AppColors.glassBorder.withOpacity(0.04),
                                width: 0.8),
                          ),
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.voidBlack.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDir
                                    ? Icons.folder_rounded
                                    : Icons.audiotrack_rounded,
                                color: isDir
                                    ? AppColors.electricCyan.withOpacity(0.8)
                                    : AppColors.neonGreen.withOpacity(0.8),
                                size: 18,
                              ),
                            ),
                            title: Text(
                              isDir ? name : name.toUpperCase(),
                              style: TextStyle(
                                color: isDir
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight:
                                    isDir ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isDir
                                ? const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textMuted, size: 20)
                                : const Icon(Icons.play_arrow_rounded,
                                    color: AppColors.neonGreen, size: 18),
                            onTap: () async {
                              if (isDir) {
                                setState(() {
                                  _currentPath = entity.path;
                                });
                                _loadDirectoryContents();
                              } else {
                                final playbackService =
                                    ref.read(playbackServiceProvider);
                                final songName = p
                                    .basenameWithoutExtension(entity.path)
                                    .toUpperCase();
                                final parentName = p
                                    .basename(entity.parent.path)
                                    .toUpperCase();
                                final folderFiles = _entities
                                    .where((e) => e is File)
                                    .map((e) => e.path)
                                    .toList();

                                await playbackService.playTrack(
                                  filePath: entity.path,
                                  title: songName,
                                  artist: 'FOLDER AUDIO',
                                  album: parentName,
                                  duration: const Duration(seconds: 240),
                                  queue: folderFiles,
                                );

                                if (mounted) {
                                  GoRouter.of(context).go(AppRoutes.home);
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildPermissionDeniedBody(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppColors.obsidianDark.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_rounded,
                  color: AppColors.cyberPink, size: 64),
              const SizedBox(height: 16),
              Text(
                'STORAGE ACCESS REQUIRED',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'To index and browse your physical audio files offline, UltraMP3 needs permission to read files on your local device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyberPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () async {
                  final granted = await ref
                      .read(permissionServiceProvider)
                      .requestStoragePermission();
                  if (granted) {
                    _initDirectory();
                  }
                },
                child: const Text('Grant Access',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
