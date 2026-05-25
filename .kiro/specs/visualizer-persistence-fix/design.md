# Visualizer Persistence Bugfix Design

## Overview

The visualizer selection is not persisting between app launches. When users select a visualizer style or variation, the app defaults back to `spectrumBars` with variation `0` on restart instead of remembering the user's last selection.

**Root Cause**: The visualizer selection handler in `PlayerScreen` updates local state but does NOT call the corresponding `StorageService` methods to persist the selection to Hive.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug - when visualizer style or variation is changed but not persisted
- **Property (P)**: The desired behavior - visualizer style and variation should be saved to Hive and restored on app launch
- **Preservation**: Existing behavior for all other settings and interactions that must remain unchanged
- **StorageService**: Service class in `lib/core/services/storage_service.dart` that wraps Hive operations
- **PlayerScreen**: Main player UI widget in `lib/features/player/presentation/screens/player_screen.dart`
- **Hive**: NoSQL database used for local persistence in this Flutter app

## Bug Details

### Bug Condition

The bug manifests when a user selects a visualizer style or cycles through visualizer variations in the player UI. The `PlayerScreen` widget updates its local `_visualizerStyle` and `_visualizerVariation` state variables but fails to call the corresponding `StorageService` save methods.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type Map<String, dynamic> with keys 'action' and 'style'
  OUTPUT: boolean

  IF input['action'] == 'select_style' THEN
    RETURN NOT isVisualizerStylePersisted(input['style'])
  ELSE IF input['action'] == 'cycle_variation' THEN
    RETURN NOT isVisualizerVariationPersisted(input['variation'])
  ELSE
    RETURN false
  END IF
END FUNCTION

FUNCTION isVisualizerStylePersisted(style)
  // This would return true if setVisualizerStyle was called
  // Currently always returns false because save is never called
  RETURN false
END FUNCTION

FUNCTION isVisualizerVariationPersisted(variation)
  // This would return true if setVisualizerVariation was called
  // Currently always returns false because save is never called
  RETURN false
END FUNCTION
```

### Examples

- **Example 1 - Style Selection**: User taps "Waveform" visualizer style
  - Expected: `storage.setVisualizerStyle('waveform')` is called, app restarts with Waveform
  - Actual: Only local state updated, app restarts with `spectrumBars`

- **Example 2 - Variation Cycling**: User long-presses to cycle to variation 2 of "SpectrumBars"
  - Expected: `storage.setVisualizerVariation(2)` is called, app restarts with variation 2
  - Actual: Only local state updated, app restarts with variation 0

- **Example 3 - Style + Variation Combo**: User selects "CircularSpectrum" and cycles to variation 3
  - Expected: Both style and variation are persisted
  - Actual: Both are lost on restart

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- All other player settings (dialer transparency, opacity, skin type, etc.) must continue to work
- Visualizer rendering must continue to function correctly
- All other storage operations (favorites, playlists, queue state) must remain unaffected
- UI interactions (button clicks, gestures) must continue to work as before

**Scope:**
All inputs that do NOT involve visualizer selection changes should be completely unaffected by this fix. This includes:
- Dialer interactions
- Playback controls (play, pause, skip, etc.)
- Other settings changes
- Any non-visualizer UI interactions

## Hypothesized Root Cause

Based on code analysis, the root cause is clear:

1. **Missing Save Call for Visualizer Style**: In `PlayerScreen` lines 2109-2113, when a user taps to select a visualizer style, the code updates local state but does NOT call `storage.setVisualizerStyle(style.name)`. The method exists in `StorageService` but is never invoked.

2. **Missing Save Call for Visualizer Variation**: When cycling variations (lines 1140-1143), the code updates `_visualizerVariation` but does NOT call `storage.setVisualizerVariation(newValue)`.

3. **Load Logic is Correct**: The initialization code (lines 263-270) correctly reads from storage using `getVisualizerStyle()` and `getVisualizerVariation()`. The persistence layer is working; only the write operations are missing.

## Correctness Properties

Property 1: Bug Condition - Visualizer Style Persistence

_For any_ user action that selects a visualizer style (tapping a style in the visualizer picker), the fixed `PlayerScreen` SHALL call `storage.setVisualizerStyle(style.name)` to persist the selection, ensuring the style is restored on app restart.

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition - Visualizer Variation Persistence

_For any_ user action that cycles the visualizer variation (long-press or variation toggle), the fixed `PlayerScreen` SHALL call `storage.setVisualizerVariation(variation)` to persist the variation, ensuring it is restored on app restart.

**Validates: Requirements 2.3, 2.4**

Property 3: Preservation - Non-Visualizer Settings

_For any_ user action that does NOT involve visualizer selection (playback controls, other settings, UI interactions), the fixed code SHALL produce exactly the same behavior as the original code, preserving all existing functionality.

**Validates: Requirements 3.1, 3.2, 3.3**

## Fix Implementation

### Changes Required

**File**: `lib/features/player/presentation/screens/player_screen.dart`

**Function**: Visualizer style selection handler (around line 2109)

**Specific Changes**:

1. **Add storage call for visualizer style selection** (around line 2113):
```dart
onTap: () {
  setState(() {
    _visualizerStyle = style;
    _visualizerVariation = 0;
  });
  // ADD: Persist the visualizer style selection
  storage.setVisualizerStyle(style.name);
  // ADD: Persist the variation reset to 0
  storage.setVisualizerVariation(0);
  Navigator.pop(context);
  _showFeedbackGlow(
      context,
      'VISUALIZER: ${style.name.toUpperCase()}',
      activeSkin.textColor);
},
```

2. **Add storage call for visualizer variation cycling** (around line 1143):
```dart
setState(() {
  final int maxVars = _getMaxVariations(_visualizerStyle);
  _visualizerVariation = (_visualizerVariation + 1) % maxVars;
});
// ADD: Persist the new variation value
storage.setVisualizerVariation(_visualizerVariation);
_showFeedbackGlow(
    context,
    'VIS VARIATION: ${_visualizerVariation + 1}',
    activeSkin.textColor);
```

**Note**: The `storage` variable is already available in the scope (line 263: `final storage = ref.read(storageServiceProvider);`), so no additional imports or provider lookups are needed.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis.

**Test Plan**: Write tests that simulate visualizer selection and verify persistence. Run these tests on the UNFIXED code to observe failures.

**Test Cases**:
1. **Style Selection Persistence Test**: Select a visualizer style, simulate app restart, verify style is restored (will fail on unfixed code)
2. **Variation Cycling Persistence Test**: Cycle through variations, simulate app restart, verify variation is restored (will fail on unfixed code)
3. **Combined Style + Variation Test**: Select style and cycle variation, verify both are restored (will fail on unfixed code)
4. **Edge Case - Out of Range**: Test with maximum variation value (may fail on unfixed code)

**Expected Counterexamples**:
- Visualizer style defaults to `spectrumBars` on restart regardless of user selection
- Visualizer variation defaults to `0` on restart regardless of user cycling

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function persists the selection correctly.

**Pseudocode:**
```
FOR ALL selectionAction WHERE isBugCondition(selectionAction) DO
  result := handleVisualizerSelection(selectionAction)
  ASSERT isPersisted(result.style) = true
  ASSERT isPersisted(result.variation) = true
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalFunction(input) = fixedFunction(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain
- It catches edge cases that manual unit tests might miss
- It provides strong guarantees that behavior is unchanged for non-visualizer interactions

**Test Plan**: Observe behavior on UNFIXED code first for non-visualizer interactions, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Playback Controls Preservation**: Verify play/pause/skip continue to work
2. **Other Settings Preservation**: Verify dialer, skin, and other settings are unaffected
3. **UI Interactions Preservation**: Verify all gestures and button clicks work correctly
4. **Visualizer Rendering Preservation**: Verify visualizer still renders correctly with saved values

### Unit Tests

- Test `StorageService.getVisualizerStyle()` returns saved value
- Test `StorageService.getVisualizerVariation()` returns saved value
- Test `PlayerScreen` style selection updates state correctly
- Test `PlayerScreen` variation cycling updates state correctly
- Test edge cases (invalid style name, out of range variation)

### Property-Based Tests

- Generate random visualizer style selections and verify persistence
- Generate random variation values (0-3) and verify persistence
- Generate random sequences of style + variation changes and verify final state is restored
- Test that non-visualizer operations produce identical results before and after fix

### Integration Tests

- Test full app flow: select visualizer → close app → reopen app → verify selection persisted
- Test variation cycling flow: cycle variations → restart → verify variation persisted
- Test combined operations: change style, cycle variation, restart → verify both persisted
- Test visualizer rendering with saved values from storage