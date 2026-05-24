# UltraMP3 Reborn — Project Mindmap

## 🎯 UltraMP3 Reborn
> Offline music player · Flutter · Cyber-retro aesthetic (Symbian S60 + Neon/Glassmorphic)

---

### 📦 Tech Stack
- **Framework**: Flutter (Dart 3.2+)
- **State**: Riverpod (flutter_riverpod + riverpod_annotation + riverpod_generator)
- **Routing**: go_router 13.2+ (StatefulShellRoute)
- **Audio Engine**: just_audio 0.9.36 + audio_service 0.18.12
- **Audio Query**: on_audio_query 2.9.0
- **Storage**: hive_flutter 1.1.0
- **Streams**: rxdart 0.27.7
- **Typography**: google_fonts (Orbitron, Rajdhani, Outfit, ShareTechMono)
- **Code Gen**: build_runner, freezed, hive_generator, json_serializable
- **Platforms**: Android · iOS · Web · Windows · macOS · Linux

---

### 🏗️ Architecture

```
main.dart
  ├── ProviderScope
  │   ├── StorageService (Hive)
  │   └── UltraAudioHandler (audio_service + just_audio)
  └── UltraMP3App (ConsumerWidget)
      └── MaterialApp.router
          └── GoRouter
              ├── / → SplashScreen
              ├── StatefulShellRoute (4-tab bottom nav)
              │   ├── /home       → PlayerScreen (tab 0)  ⚠ (HomeScreen exists but not routed)
              │   ├── /library    → LibraryScreen (tab 1)
              │   ├── /folders    → FolderBrowserScreen (tab 2)
              │   └── /playlists  → PlaylistsScreen (tab 3)
              ├── /player → PlayerScreen (full-screen overlay)
              └── /player-settings → PlayerSettingsScreen
```

### 🔄 Data Flow

```
User tap → PlaybackService.playTrack()
  ├── Creates MediaItem from metadata
  ├── loadQueueItem() → UltraAudioHandler
  │     └── just_audio AudioSource (file/URI)
  ├── play() → _player.play()
  ├── addRecentlyPlayed() → Hive
  └── saveQueueState() → Hive

Audio Events:
  just_audio → UltraAudioHandler._transformEvent()
    → playbackState stream → audio_service notification
    → UI (StreamBuilder)
  position + duration + mediaItem
    → Rx.combineLatest3 → PositionState → UI
```

---

### 📁 Source Tree (lib/)

```
lib/
├── main.dart                              # Entry point
├── core/
│   ├── routing/
│   │   ├── app_router.dart                # GoRouter config
│   │   └── routes.dart                    # Route constants
│   ├── services/
│   │   ├── audio_handler.dart             # UltraAudioHandler (BaseAudioHandler)
│   │   ├── media_query_service.dart       # Audio file scanner
│   │   ├── permission_service.dart        # Runtime permissions
│   │   ├── playback_service.dart          # Playback orchestrator (Riverpod)
│   │   └── storage_service.dart           # Hive wrapper (5 boxes)
│   ├── theme/
│   │   ├── app_colors.dart                # Cyber color palette
│   │   └── app_theme.dart                 # Dark theme + ThemeExtension
│   └── widgets/
│       └── seek_bar.dart                  # Reusable seek slider
└── features/
    ├── splash/
    │   └── presentation/screens/
    │       └── splash_screen.dart         # Animated boot screen
    ├── shell/
    │   └── presentation/screens/
    │       └── app_shell.dart             # Bottom nav shell
    ├── home/
    │   └── presentation/screens/
    │       └── home_screen.dart           # Dashboard
    ├── library/
    │   └── presentation/screens/
    │       └── library_screen.dart        # 3-tab media library
    ├── folder_browser/
    │   └── presentation/screens/
    │       └── folder_browser_screen.dart # File system browser
    ├── playlists/
    │   └── presentation/
    │       ├── providers/
    │       │   └── playlist_providers.dart # Favorites/Recents/Playlists
    │       └── screens/
    │           └── playlists_screen.dart   # Playlist management
    ├── player/
    │   ├── domain/models/
    │   │   └── player_skin.dart           # 23 skin definitions
    │   └── presentation/
    │       ├── providers/
    │       │   ├── player_skin_provider.dart
    │       │   └── player_settings_provider.dart
    │       ├── screens/
    │       │   ├── player_screen.dart      # ★ 6647 lines (main player)
    │       │   ├── player_settings_screen.dart
    │       │   └── add_to_playlist_screen.dart
    │       └── widgets/
    │           └── mini_player.dart        # Floating mini-player bar
    └── settings/
        └── presentation/screens/
            └── settings_screen.dart        # EQ + diagnostics
```

---

### 🧩 Screens Detail

#### 1. SplashScreen (468 lines)
- Animated particle background (CustomPainter)
- Pulsing app icon + LED progress bar
- Simulated diagnostic logs
- Auto-navigates to /home

#### 2. AppShell (108 lines)
- Scaffold + BottomNavigationBar (4 tabs)
- MiniPlayer shown when not on Home tab
- Glassmorphic backdrop + skin-aware coloring

#### 3. HomeScreen (676 lines)
- Digital clock (HH:MM:SS)
- Quick actions: Library Scan, Sleep Timer
- Recently Played (horizontal scroll)
- Favorites (vertical list)
- Tap track → /player

#### 4. LibraryScreen (974 lines)
- TabBar: All Songs · Albums · Artists
- physicalSongsProvider (FutureProvider)
- Play/Favorite/Playlist actions per track
- Albums/Artists → Play All / Shuffle

#### 5. FolderBrowserScreen (576 lines)
- Directory tree + audio file listing
- Current path breadcrumb
- "Play Folder" queues directory contents

#### 6. PlaylistsScreen (686 lines)
- 4 smart cards: Favorites, Recently Played, Recently Added, Most Played
- Custom user playlists (create/delete)
- Play All / Shuffle per playlist

#### 7. PlayerScreen ★ (6647 lines) — Core
- **Visualizer Engine** — 21 styles × 3–4 variations (~70 modes)
  - spectrumBars · waveform · circularSpectrum · particleReactive · liquidFluid
  - breathingRings · retroWinamp · albumArtReactive · combinedUltra · solarFlares
  - vortexOrbit · rippleWaves · particleWaveFlow · cosmicTunnel · orbitalGlow
  - frequencyLaser · dnaHelix · audioMatrixGrid · blackHoleStars
  - _VisualizerPainter (~1500 lines) — 10 amplitude bands + beat simulator
- **Dial Styles**: circular (iPod) · rectangular (D-pad) · digitalToggles (synth)
- **Skins**: 8 Skeuomorphic (S60) + 15 Flat Minimal (23 total)
- **Equalizer**: 5-band (−12/+12 dB) · 14 presets · AndroidEqualizer native
  - _SkeuomorphicEqualizerPanel + _SkeuomorphicKnob widgets
- **Queue Display**: Upcoming 5 tracks
- **Marquee Text**: Auto-scrolling track info
- **Responsive**: Portrait (stack) + Landscape (side-by-side)
- **Persistence**: shuffle/loop/volume/EQ/queue restored on init

#### 8. PlayerSettingsScreen (342 lines)
- Classic Skeuomorphic / Flat Minimal toggle
- Dialer transparency, Visualizer transparency
- Album art vs Visualizer toggle

#### 9. AddToPlaylistScreen (365 lines)
- Existing playlist list + create new + add current

#### 10. SettingsScreen (424 lines)
- Glow toggle · Glassmorphic toggle
- 3-band EQ (Bass/Mid/Treble) + presets
- Library diagnostics (indexed files, folders, Hive info)

---

### 🎨 Skin System (23 Skins)

#### Skeuomorphic (8)
| # | Skin | Aesthetic |
|---|------|-----------|
| 1 | S60 Classic Grey | Symbian default |
| 2 | Symbian Classic Blue | Default skin |
| 3 | Obsidian Void | Dark glass |
| 4 | Matrix Amber | Green phosphor |
| 5 | Ferrari Special Edition | Red/black luxury |
| 6 | Neon Aurora Green | Cyberpunk green |
| 7 | Desert Horizon Gold | Warm sands |
| 8 | Glacier Crystalline Ice | Frosted blue |

#### Flat Minimal (15)
Cyberpunk · Mint Forest · Peach Blossom · Dark Monochrome · Amethyst Violet
Amber Sunset · Polar Cyan · Neon Sunset · Sakura Pastel · Glassmorphic
Lo-Fi Rain · Minimal Techno · Vinyl Noir · Pastel Lavender · Sakura Light

Each skin defines: colors, gradients, LCD style, button/icon colors, LED color, bg asset path.

---

### ⚙️ Equalizer Presets (14)
Flat · Rock · Pop · Jazz · Bass & Treble · Mids · Classic · Live · Dance · Soft · No Bass · No Mids · No Treble · Custom

---

### 🗄️ Hive Storage Schema

| Box | Purpose | Key Examples |
|-----|---------|-------------|
| settings | App config | glowEnabled, glassEnabled, dialerOpacity, visualizerOpacity, loopMode, shuffleMode, volume, skinType, eqBands, eqPreset |
| favorites | Favorite tracks | TrackID → AppTrack |
| recently_played | Recents (capped) | TrackID → AppTrack |
| playlists | Custom playlists | PlaylistName → List<AppTrack> |
| active_queue | Session resume | queueTracks, currentIndex, position |

---

### 📊 Visualizer Styles (21)

| # | Style | Variations |
|---|-------|-----------|
| 1 | spectrumBars | 3 |
| 2 | waveform | 3 |
| 3 | circularSpectrum | 4 |
| 4 | particleReactive | 3 |
| 5 | liquidFluid | 3 |
| 6 | breathingRings | 3 |
| 7 | retroWinamp | 3 |
| 8 | albumArtReactive | 3 |
| 9 | combinedUltra | 3 |
| 10 | solarFlares | 3 |
| 11 | vortexOrbit | 3 |
| 12 | rippleWaves | 3 |
| 13 | particleWaveFlow | 3 |
| 14 | cosmicTunnel | 3 |
| 15 | orbitalGlow | 3 |
| 16 | frequencyLaser | 3 |
| 17 | dnaHelix | 3 |
| 18 | audioMatrixGrid | 3 |
| 19 | blackHoleStars | 3 |
| 20-21 | (additional custom) | — |

---

### 🔌 Services

| Service | File | Responsibility |
|---------|------|---------------|
| **UltraAudioHandler** | audio_handler.dart | AudioService bridge; wraps just_audio; AndroidEqualizer; notification |
| **PlaybackService** | playback_service.dart | Riverpod provider; position/duration streams; play/pause/seek/skip; queue mgmt |
| **MediaQueryService** | media_query_service.dart | Android/iOS: on_audio_query; Desktop: recursive Music dir scan; AppTrack model |
| **StorageService** | storage_service.dart | Hive singleton: get/put/delete/list for 5 boxes |
| **PermissionService** | permission_service.dart | Android 13+ audio vs storage; returns true on non-mobile |

---

### 🔐 Permissions (Android)
- Android 13+: `Permission.audio`
- Android <13: `Permission.storage`
- Audio foreground service notification

---

### 🧪 Testing
- `test/widget_test.dart` — 1 smoke test (SplashScreen renders)
- No unit tests for services, providers, or models

---

## 🧠 Full Functionality Mindmap (Text)

```
UltraMP3 Reborn
  App Boot
    SplashScreen
      animated particles + LED progress
      simulated diagnostic log feed
      auto-navigate to /home
  Navigation
    AppShell
      bottom tabs (Home/Library/Folders/Playlists)
      MiniPlayer (hidden when no track loaded)
    Routes
      / (splash)
      /home (currently PlayerScreen)
      /library
      /folders
      /playlists
      /player (slide-up PlayerScreen overlay)
      /player-settings
      /settings (constant exists but not wired)
  Media Indexing / Library
    PermissionService
      Android 13+ Permission.audio
      Android <13 Permission.storage
      Desktop/iOS: returns true
    MediaQueryService
      Mobile: on_audio_query (SongModel -> AppTrack)
      Desktop: recursive scan ~/Music fallback + duration probing via headless just_audio
      Scan progress stream (ScanStatus)
    LibraryScreen
      refresh triggers permission request + invalidates scan provider
      3 tabs: All Songs / Albums / Artists
      actions: play, favorite, add to playlist
  Playback Engine
    UltraAudioHandler
      just_audio AudioPlayer
      audio_service notification + MediaItem sync
      AndroidEqualizer effect (best-effort)
      queue loading: ConcatenatingAudioSource if fullQueue
    PlaybackService
      playTrack(filePath, metadata, optional queue)
      streams: currentMediaItem, playbackState, combined PositionState
      controls: play/pause/seek/stop/skip next/prev
  Player UX
    PlayerScreen (monolith)
      visualizer engine (simulated amplitude bands + beat)
      skins: classic/flat (23 total) + skin cycling
      dial styles: circular / rectangular / digital toggles
      equalizer UI + presets + persistence
      queue preview + track info marquee
      persistence restore: queue/shuffle/loop/volume/EQ/skin/visualizer
    PlayerSettingsScreen
      classic vs flat architecture
      dialer transparency + opacity
      visualizer transparency + opacity (classic only)
      album art vs visualizer toggle
    MiniPlayer
      shows current MediaItem + play/pause + skip
      micro progress line (PositionState)
  Folders
    FolderBrowserScreen
      initial dir: Android /storage/emulated/0 fallback external storage dir
      Desktop: Music dir fallback
      browse directories + filter audio extensions
      Play Folder: plays first track + stores queue list in Hive
  Playlists
    Storage-backed
      Favorites (songId set)
      Recently Played (capped 50)
      Custom playlists (playlistName -> list of songIds)
    PlaylistsScreen
      smart cards: Favorites / Recently Played
      simulated smart lists: Recently Added (first 20), Most Played (recents else slice)
      create/delete playlists
      view playlist songs + play all / shuffle
  Settings
    SettingsScreen (not routed)
      theme toggles (glow/glass)
      simplified EQ (bass/mid/treble mapping onto 5-band)
      offline index diagnostics (Hive + scan stats)
  Persistence (Hive)
    settings
      glow, glass, skin type, active skin
      visualizer style/variation, opacities, showAlbumArt
      loop/shuffle, volume
      equalizer preset + bands
    favorites / recently_played / playlists / active_queue
```

---

## ⚠️ Issues / Gaps Found (Code + Behavior)

### Routing / Product Gaps
1. **HomeScreen is implemented but unused**: `lib/features/home/.../home_screen.dart` exists, but `/home` routes to `PlayerScreen` (`lib/core/routing/app_router.dart`). This likely hides the intended dashboard.
2. **SettingsScreen is implemented but not reachable**: `AppRoutes.settings` exists, and `SettingsScreen` exists, but there is no router entry.
3. **Duplicate mental model of “Home vs Player”**: `PlayerScreen` is both the tab-0 “home” route and the slide-up “now playing” route.

### Simulations / Non-real Implementations
1. **Visualizer beat + amplitude are simulated** in `PlayerScreen` (synthetic beat energy around ~130 BPM). No real FFT.
2. **Splash diagnostics are simulated** (fake boot logs).
3. **Home “Library Scan” is a UI simulator dialog** (not the actual scan provider).
4. **Playlists smart lists are simulated**:
   - Recently Added: uses `physicalSongs.take(20)` (not file timestamps)
   - Most Played: uses recently played list or arbitrary slice

### Hardcodes / Magic Defaults
1. **Desktop duration defaults to 240s** when probing fails: `MediaQueryService`.
2. **Folder play uses duration 240s** and hardcoded metadata: artist `FOLDER AUDIO`.
3. **Desktop scan uses placeholder metadata**: artist `LOCAL DRIVE`, title/album forced uppercase and inferred from filename/parent folder.
4. **Queue metadata placeholders** in `PlaybackService.playTrack(queue: ...)` uses basename + `Unknown Artist` for non-active items.
5. **Android initial folder** hardcoded to `/storage/emulated/0`.

### Maintainability / Quality
1. **PlayerScreen is extremely oversized** (6k+ lines): hard to test, risky to change.
2. **Static analysis debt**: `flutter analyze` reports ~467 issues, mostly deprecated `withOpacity`, unused locals/elements, missing `const`, and style lints.
3. **Logging via `print`** in production code (audio handler + scanning + folder browser).
4. **Hive uses raw string keys** (no adapters/models) which makes refactors brittle.
5. **Tests are minimal** (single widget smoke test).

---

## 🧭 Roadmap (Pragmatic, High-Signal)

### Phase 0: Product Wiring Fixes (1-2 days)
1. Decide UX: `HomeScreen` as `/home` and `PlayerScreen` as `/player` only, or keep current.
2. Wire missing routes:
   - `/home` target (likely `HomeScreen`)
   - `/settings` route to `SettingsScreen` (and add entry point button somewhere)
3. Remove/merge duplicate entry points (if `/home` and `/player` are both PlayerScreen).

### Phase 1: Stabilization (2-5 days)
1. Replace `print` with a minimal logger (or gated debug logging).
2. Fix the high-impact analyzer warnings first:
   - unused locals/elements in PlayerScreen
   - deprecated `withOpacity` usage
3. Normalize “smart playlists” to be explicit:
   - mark simulated ones as simulated in UI
   - or implement real data sources (file timestamps, play counts)

### Phase 2: Data + Persistence Hardening (3-7 days)
1. Introduce typed models for Hive payloads (even if still using primitives, centralize keys).
2. Improve queue persistence:
   - persist currentIndex + position
   - persist full metadata for queue items (avoid placeholders)
3. Desktop scanning performance:
   - avoid probing every file on startup (cache durations)
   - incremental scan + change detection

### Phase 3: Modularize Player (ongoing, big win)
1. Split `PlayerScreen` into:
   - visualizer engine/painters
   - equalizer module
   - controls/dial module
   - queue + metadata widgets
2. Add focused tests around:
   - PlaybackService queue behavior
   - StorageService schema defaults/migrations
   - MediaQueryService desktop scan edge cases

### Phase 4: Next Features (optional)
1. Real audio-reactive visualizer (FFT) if feasible on all target platforms.
2. True “Most Played” + “Recently Added” (play counts + file timestamps) with migration.
3. Import/export playlists + settings.


---

### 🚀 Key Observations

1. **PlayerScreen (6647 lines)** is massively oversized — contains all visualizer painting, EQ UI, dial controls, sub-widgets as private classes. Top refactoring target.

2. **Simulated beat engine** — visualizer uses software beat simulator (~130 BPM kick, snare offset) instead of real FFT analysis (just_audio limitation).

3. **Desktop audio scanning** — manual Music directory traversal + temp AudioPlayer for duration probing (no on_audio_query on desktop).

4. **No Hive code generation** — uses raw string keys across 5 boxes, no TypeAdapter despite hive_generator in deps.

5. **Fully offline** — zero network calls, no backend, no auth.

6. **10 background images** in assets/images/ used for skin backgrounds.

7. **Android-specific features**: AndroidEqualizer (native EQ), audio_service (background notification). Gracefully degrade elsewhere.

8. **Reference design assets** in `skins/`, `flatskins/`, `visualizations/`, `new visualizers/` — not loaded at runtime, for design reference only.
