import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/audio_handler.dart';
import 'core/services/playback_service.dart';

void main() async {
  // 1. Ensure engine framework is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Hive local persistent cache
  final storageService = StorageService();
  await storageService.init();

  // 2b. Initialize C++ SoLoud audio engine
  await SoLoud.instance.init();

  // 3. Spin up Android Background Audio Service channel
  final audioHandler = await AudioService.init(
    builder: () => UltraAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ultramp3.reborn.channel.audio',
      androidNotificationChannelName: 'UltraMP3 Reborn Playback',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidNotificationClickStartsActivity: true,
    ),
  );

  // 4. Run application wrapped in Riverpod ProviderScope
  runApp(
    ProviderScope(
      overrides: [
        // Inject our pre-initialized local database service
        storageServiceProvider.overrideWithValue(storageService),
        // Inject our pre-initialized background audio system handler
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const UltraMP3App(),
    ),
  );
}

class UltraMP3App extends ConsumerWidget {
  const UltraMP3App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'UltraMP3 Reborn',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Enforce dark void mode
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
