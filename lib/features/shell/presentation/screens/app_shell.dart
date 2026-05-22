import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';

import 'package:ultramp3/features/player/presentation/widgets/mini_player.dart';
import 'package:ultramp3/core/theme/app_colors.dart';
import 'package:ultramp3/features/player/presentation/providers/player_skin_provider.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSkin = ref.watch(playerSkinProvider);

    return Scaffold(
      extendBody: true, // Allows content to flow behind glassmorphic bottom bar
      body: Stack(
        children: [
          // Navigated tab viewport
          Positioned.fill(
            child: navigationShell,
          ),
          
          // Floating Mini Player (Positioned at bottom, above bottom bar - hidden when viewing S60 Player on Tab 0!)
          if (navigationShell.currentIndex != 0)
            Positioned(
              left: 12,
              right: 12,
              bottom: kBottomNavigationBarHeight + 20,
              child: const MiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 0.8),
          ),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: SafeArea(
              top: false,
              bottom: true,
              child: BottomNavigationBar(
                currentIndex: navigationShell.currentIndex,
                backgroundColor: AppColors.obsidianDark.withOpacity(0.7),
                selectedItemColor: activeSkin.textColor,
                unselectedItemColor: AppColors.textMuted,
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home, color: activeSkin.textColor),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.music_note_outlined),
                    activeIcon: Icon(Icons.music_note, color: activeSkin.textColor),
                    label: 'Library',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.folder_open_outlined),
                    activeIcon: Icon(Icons.folder, color: activeSkin.textColor),
                    label: 'Folders',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.queue_music_outlined),
                    activeIcon: Icon(Icons.queue_music, color: activeSkin.textColor),
                    label: 'Playlists',
                  ),
                ],
                onTap: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
