import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:just_audio/just_audio.dart';

import 'permission_service.dart';

/// ScanStatus represents precise real-time indexing progression
class ScanStatus {
  final double progress;
  final String currentPath;
  final int songsIndexed;
  final bool isCompleted;

  ScanStatus({
    required this.progress,
    required this.currentPath,
    required this.songsIndexed,
    this.isCompleted = false,
  });
}

/// AppTrack represents a physical or scanned audio track in the UltraMP3 application.
class AppTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final int size;

  AppTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'filePath': filePath,
        'durationMs': duration.inMilliseconds,
        'size': size,
      };

  factory AppTrack.fromJson(Map<String, dynamic> json) => AppTrack(
        id: json['id'] as String,
        title: json['title'] as String,
        artist: json['artist'] as String,
        album: json['album'] as String,
        filePath: json['filePath'] as String,
        duration: Duration(milliseconds: json['durationMs'] as int),
        size: json['size'] as int,
      );
}

Future<Directory> getMusicDirectoryFallback() async {
  try {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final dir = Directory(p.join(userProfile, 'Music'));
        if (await dir.exists()) return dir;
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final dir = Directory(p.join(home, 'Music'));
        if (await dir.exists()) return dir;
      }
    }
  } catch (_) {}
  return await getApplicationDocumentsDirectory();
}

final mediaQueryServiceProvider = Provider<MediaQueryService>((ref) {
  final permissionService = ref.watch(permissionServiceProvider);
  return MediaQueryService(permissionService);
});

final physicalSongsProvider = FutureProvider<List<AppTrack>>((ref) async {
  final mediaQuery = ref.watch(mediaQueryServiceProvider);
  return mediaQuery.getSongs();
});

class MediaQueryService {
  final PermissionService _permissionService;
  final OnAudioQuery _audioQuery = OnAudioQuery();

  final _scanController = StreamController<ScanStatus>.broadcast();
  Stream<ScanStatus> get scanStream => _scanController.stream;

  MediaQueryService(this._permissionService);

  /// Scan and retrieve all physical songs on the system.
  Future<List<AppTrack>> getSongs() async {
    final hasPerm = await _permissionService.hasStoragePermission();
    if (!hasPerm) {
      _scanController.add(ScanStatus(
          progress: 0.0, currentPath: "Permission denied", songsIndexed: 0));
      return [];
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        _scanController.add(ScanStatus(
            progress: 0.2,
            currentPath: "Accessing media system...",
            songsIndexed: 0));
        final List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        _scanController.add(ScanStatus(
            progress: 0.6,
            currentPath: "Processing track list...",
            songsIndexed: songs.length));
        final list = songs.map((song) {
          final title =
              song.title.isNotEmpty ? song.title : (song.displayNameWOExt);
          final artist = (song.artist != null && song.artist != '<unknown>')
              ? song.artist!
              : 'Unknown Artist';
          final album = (song.album != null && song.album != '<unknown>')
              ? song.album!
              : 'Unknown Album';

          return AppTrack(
            id: song.data,
            title: title,
            artist: artist,
            album: album,
            filePath: song.data,
            duration: Duration(milliseconds: song.duration ?? 0),
            size: song.size,
          );
        }).toList();

        _scanController.add(ScanStatus(
          progress: 1.0,
          currentPath: "Scan successful! Indexed ${list.length} tracks.",
          songsIndexed: list.length,
          isCompleted: true,
        ));
        return list;
      } catch (e) {
        _scanController.add(ScanStatus(
            progress: 1.0,
            currentPath: "Scan error: $e",
            songsIndexed: 0,
            isCompleted: true));
        return [];
      }
    } else {
      return _scanDesktopMusicDirectories();
    }
  }

  /// Traverses user music directory recursively on Desktop systems to find audio files.
  Future<List<AppTrack>> _scanDesktopMusicDirectories() async {
    final List<AppTrack> tracks = [];
    final List<File> audioFiles = [];

    _scanController.add(ScanStatus(
        progress: 0.05,
        currentPath: "Initializing local disk scanner...",
        songsIndexed: 0));

    try {
      final Directory musicDir = await getMusicDirectoryFallback();
      if (!await musicDir.exists()) {
        _scanController.add(ScanStatus(
            progress: 1.0,
            currentPath: "Music directory not found",
            songsIndexed: 0,
            isCompleted: true));
        return [];
      }

      _scanController.add(ScanStatus(
          progress: 0.1,
          currentPath: "Cataloging filesystem nodes...",
          songsIndexed: 0));

      // Fast Pass: Get all audio files recursively
      await for (final entity
          in musicDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.mp3' ||
              ext == '.wav' ||
              ext == '.flac' ||
              ext == '.m4a' ||
              ext == '.ogg') {
            audioFiles.add(entity);
          }
        }
      }

      final total = audioFiles.length;
      if (total == 0) {
        _scanController.add(ScanStatus(
            progress: 1.0,
            currentPath: "No playable tracks found.",
            songsIndexed: 0,
            isCompleted: true));
        return [];
      }

      // Headless prober player instance
      final player = AudioPlayer();

      for (int i = 0; i < total; i++) {
        final file = audioFiles[i];
        final fileName = p.basenameWithoutExtension(file.path);
        final size = await file.length();

        // Split Artist - Title if formatted
        String title = fileName.toUpperCase();
        String artist = 'LOCAL DRIVE';

        if (fileName.contains(' - ')) {
          final parts = fileName.split(' - ');
          if (parts.length >= 2) {
            artist = parts[0].trim().toUpperCase();
            title = parts.sublist(1).join(' - ').trim().toUpperCase();
          }
        }

        Duration duration = const Duration(seconds: 240); // default

        try {
          // Probe actual duration sequentially
          await player.setAudioSource(AudioSource.file(file.path),
              preload: true);
          if (player.duration != null) {
            duration = player.duration!;
          }
        } catch (e) {
          print('Probing duration error for ${file.path}: $e');
        }

        final track = AppTrack(
          id: file.path,
          title: title,
          artist: artist,
          album: p.basename(file.parent.path).toUpperCase(),
          filePath: file.path,
          duration: duration,
          size: size,
        );

        tracks.add(track);

        // Yield precise real-time scanning status
        final progressPct = 0.1 + (i / total) * 0.9;
        _scanController.add(ScanStatus(
          progress: progressPct,
          currentPath: file.path,
          songsIndexed: i + 1,
        ));
      }

      await player.dispose();

      _scanController.add(ScanStatus(
        progress: 1.0,
        currentPath: "Offline scanning completed successfully!",
        songsIndexed: total,
        isCompleted: true,
      ));
    } catch (e) {
      print('Desktop scanning error: $e');
      _scanController.add(ScanStatus(
        progress: 1.0,
        currentPath: "Scan error: $e",
        songsIndexed: tracks.length,
        isCompleted: true,
      ));
    }

    return tracks;
  }
}
