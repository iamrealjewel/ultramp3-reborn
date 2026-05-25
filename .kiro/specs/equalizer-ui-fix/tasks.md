# Equalizer UI Fix - Tasks

## Overview

This spec fixes equalizer UI issues in UltraMP3 Reborn:
1. Reorder presets with brand presets at the top
2. Change preset selector from horizontal to vertical list
3. Fix band indicators to show correct dB values
4. Fix volume indicator overflow

## Prerequisites

- Flutter SDK configured for the project
- Access to `lib/features/player/presentation/screens/player_screen.dart`
- Access to `lib/features/settings/presentation/screens/settings_screen.dart`
- Test framework available (run `flutter test` to verify)

---

## Tasks

- [ ] 1. Reorder presets in player_screen.dart with brand presets at top
  - Reorder `_presetNames` static list to put Beats Audio, Harman Kardon, Sony ClearBass, Sennheiser Club at the top
  - Ensure the order matches: Beats Audio, Harman Kardon, Sony ClearBass, Sennheiser Club, Flat, Rock, Pop, Jazz, Bass & Treble, Mids, Classic, Live, Dance, Soft, Bose Signature, No Bass, No Mids, No Treble, Custom
  - Verify no other code depends on the old preset order

- [ ] 2. Reorder presets in settings_screen.dart to match player_screen.dart
  - Reorder `_presets` map keys to match the new order from Task 1
  - Ensure consistency between both files

- [ ] 3. Redesign preset selector from horizontal ListView to vertical dropdown
  - Replace horizontal ListView with PopupMenuButton in `_SkeuomorphicEqualizerPanel`
  - Display presets as a vertical list with checkmark for selected preset
  - Style the dropdown button to show "EQ: [PRESET_NAME]" with dropdown arrow
  - Ensure the dropdown matches the skeuomorphic theme

- [ ] 4. Fix band indicator display to show correct dB values
  - Verify slider value matches displayed dB value
  - Add 0dB center line indicator behind sliders
  - Ensure band indicators are synchronized with slider positions
  - Test with different presets to confirm values display correctly

- [ ] 5. Fix volume indicator overflow
  - Reduce container width from 90 to 80 pixels
  - Use Expanded widgets for segments to distribute evenly
  - Reduce segment heights slightly to prevent overflow
  - Shorten "VOLUME" label to "VOL" to save space
  - Verify the volume bar fits within the UI constraints

- [ ] 6. Build and verify all changes
  - Run `flutter build apk --debug` to verify no compilation errors
  - Test preset selection and switching
  - Test volume indicator interaction
  - Verify band indicators display correctly with different presets
  - Confirm no regressions in other UI elements

---

## Task Dependency Graph

```
Task 1 (Reorder presets in player_screen.dart)
  ↓
Task 2 (Reorder presets in settings_screen.dart)
  ↓
Task 3 (Redesign preset selector)
  ↓
Task 4 (Fix band indicators)
  ↓
Task 5 (Fix volume indicator)
  ↓
Task 6 (Build and verify)
```

---

## Notes

- All changes are UI-only, no core logic modifications
- Preset order must be consistent between player_screen.dart and settings_screen.dart
- The PopupMenuButton should maintain the skeuomorphic aesthetic
- Volume indicator must fit within the 8.8 pixel constraint mentioned in design
- All existing functionality must be preserved
