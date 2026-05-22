import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'permission_service.dart';

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

  MediaQueryService(this._permissionService);

  /// Scan and retrieve all physical songs on the system.
  Future<List<AppTrack>> getSongs() async {
    final hasPerm = await _permissionService.hasStoragePermission();
    if (!hasPerm) {
      return [];
    }

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final List<SongModel> songs = await _audioQuery.querySongs(
          sortType: SongSortType.TITLE,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        );

        return songs.map((song) {
          final title = song.title.isNotEmpty ? song.title : (song.displayNameWOExt);
          final artist = (song.artist != null && song.artist != '<unknown>') ? song.artist! : 'Unknown Artist';
          final album = (song.album != null && song.album != '<unknown>') ? song.album! : 'Unknown Album';
          
          return AppTrack(
            id: song.data, // filePath is the best stable identifier
            title: title,
            artist: artist,
            album: album,
            filePath: song.data,
            duration: Duration(milliseconds: song.duration ?? 0),
            size: song.size,
          );
        }).toList();
      } catch (e) {
        print('Error querying songs with on_audio_query: $e');
        return [];
      }
    } else {
      // Fallback for Windows/macOS/Linux: Scan the system Music folder
      return _scanDesktopMusicDirectories();
    }
  }

  /// Traverses user music directory recursively on Desktop systems to find audio files.
  Future<List<AppTrack>> _scanDesktopMusicDirectories() async {
    final List<AppTrack> tracks = [];
    try {
      final Directory musicDir = await getMusicDirectoryFallback();

      if (await musicDir.exists()) {
        await for (final entity in musicDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (ext == '.mp3' || ext == '.wav' || ext == '.flac' || ext == '.m4a' || ext == '.ogg') {
              final file = entity;
              final fileName = p.basenameWithoutExtension(file.path);
              final size = await file.length();
              
              // Add physical track
              tracks.add(AppTrack(
                id: file.path,
                title: fileName.toUpperCase(),
                artist: 'Local Drive',
                album: p.basename(file.parent.path).toUpperCase(),
                filePath: file.path,
                duration: const Duration(seconds: 240), // fallback estimate duration if metadata parsing isn't active
                size: size,
              ));
            }
          }
        }
      }
    } catch (e) {
      print('Desktop scanning error: $e');
    }
    return tracks;
  }
}
