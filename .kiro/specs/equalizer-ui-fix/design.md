# Equalizer UI Fix Design

## Problem Statement

The equalizer UI has several issues that need to be addressed:

1. **Band indicators don't reflect values correctly** - When selecting different presets, the band sliders don't properly reflect the actual dB values
2. **Volume level indicator overflow** - The volume indicator overflows its 8.8 pixel constraint
3. **Preset selector layout** - Presets are displayed side-by-side horizontally, making it hard to see all options; should be a vertical list
4. **Preset ordering** - Popular brand presets (Beats, Harman, Sennheiser, Sony) should appear at the top of the list

## Current State Analysis

### Band Indicator Issue
- The `_SkeuomorphicEqualizerPanel` displays band values using `${bands[index].toInt()}dB`
- The slider uses `bands[index].clamp(minDb, maxDb)` for its value
- The issue is that the display shows the raw dB value but the slider may not visually match when presets are applied

### Volume Indicator Overflow
- The `_buildSkeuomorphicVolumeBar` has a fixed width of 90 with 10 segments of 4.5px each
- 10 segments × 4.5px = 45px, plus 4px padding = 49px total
- The 8.8px overflow might be from text labels or container constraints

### Preset Selector Current Layout
- Uses `ListView.separated` with `scrollDirection: Axis.horizontal`
- Presets displayed in a single horizontal row
- Hard to browse all options on smaller screens

### Current Preset Order
```dart
'Flat', 'Rock', 'Pop', 'Jazz', 'Bass & Treble', 'Mids', 'Classic', 'Live', 
'Dance', 'Soft', 'Beats Audio', 'Harman Kardon', 'Sony ClearBass', 
'Bose Signature', 'Sennheiser Club', 'No Bass', 'No Mids', 'No Treble', 'Custom'
```

## Design Solution

### 1. Band Indicator Fix
- Ensure the slider value directly reflects the band value
- Add visual indicators showing min/max dB boundaries
- Add a center line at 0dB for reference

### 2. Volume Indicator Fix
- Constrain the container to prevent overflow
- Adjust text label sizing or use FittedBox

### 3. Preset Selector Redesign
- Change from horizontal `ListView` to vertical `ListView`
- Use a dropdown or modal bottom sheet for preset selection
- Group presets logically with headers

### 4. Preset Reordering
New order with brand presets at top:
```dart
'Beats Audio', 'Harman Kardon', 'Sony ClearBass', 'Sennheiser Club',
'Flat', 'Rock', 'Pop', 'Jazz', 'Bass & Treble', 'Mids', 'Classic', 
'Live', 'Dance', 'Soft', 'Bose Signature', 'No Bass', 'No Mids', 'No Treble', 'Custom'
```

## Implementation Plan

### Phase 1: Preset Reordering
- Reorder preset arrays in both player_screen.dart and settings_screen.dart
- Ensure consistency across both files

### Phase 2: Preset Selector UI Redesign
- Change horizontal ListView to vertical dropdown
- Use PopupMenuButton with vertical list
- Add visual feedback for selected preset

### Phase 3: Band Indicator Fix
- Add 0dB center line indicator
- Ensure slider and text display are synchronized
- Add min/max labels for reference

### Phase 4: Volume Indicator Fix
- Constrain container width properly
- Add overflow handling

## Files to Modify

1. `lib/features/player/presentation/screens/player_screen.dart`
   - Reorder `_presetNames` array
   - Redesign preset selector in `_SkeuomorphicEqualizerPanel`
   - Fix band indicator display
   - Fix volume indicator overflow

2. `lib/features/settings/presentation/screens/settings_screen.dart`
   - Reorder `_presets` map keys
   - Update preset selector if needed

## Success Criteria

- [ ] Presets are displayed in a vertical list
- [ ] Brand presets (Beats, Harman, Sony, Sennheiser) appear at the top
- [ ] Band indicators show correct dB values matching slider positions
- [ ] Volume indicator doesn't overflow
- [ ] All existing functionality preserved