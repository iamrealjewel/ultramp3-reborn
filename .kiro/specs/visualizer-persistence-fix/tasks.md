# Implementation Plan

## Overview

This plan implements the visualizer persistence fix for UltraMP3 Reborn. The bug causes visualizer style and variation selections to be lost between app launches because `PlayerScreen` updates local state but never calls `StorageService` save methods.

## Prerequisites

- Flutter SDK configured for the project
- Access to `lib/features/player/presentation/screens/player_screen.dart`
- Access to `lib/core/services/storage_service.dart`
- Test framework available (run `flutter test` to verify)
- No breaking changes to dependencies required

---

## Task 1: Write Bug Condition Exploration Test

- **Property 1: Bug Condition** - Visualizer Style and Variation Not Persisted
- **IMPORTANT**: Write this property-based test BEFORE implementing the fix
- **GOAL**: Surface counterexamples that demonstrate the bug exists
- **Scoped PBT Approach**: Scope the property to concrete failing cases to ensure reproducibility

**Test Details from Design:**

The bug condition is triggered when:
- User selects a visualizer style (action: 'select_style') - style is NOT persisted
- User cycles visualizer variation (action: 'cycle_variation') - variation is NOT persisted

**Test Implementation:**
- Test that `storage.getVisualizerStyle()` returns null/empty after style selection on unfixed code
- Test that `storage.getVisualizerVariation()` returns 0 after variation cycling on unfixed code
- Test that `calculatePrice(0, 10)` throws exception instead of returning 'N/A' (adapted for this context)

**Expected Counterexamples:**
- After selecting "Waveform" style: `getVisualizerStyle()` returns `null` or `"spectrumBars"` instead of `"waveform"`
- After cycling to variation 2: `getVisualizerVariation()` returns `0` instead of `2`

**Run test on UNFIXED code:**
- **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bug exists)
- Document counterexamples found to understand root cause

**Mark task complete when:**
- [x] Test is written following PBT conventions
- [x] Test is run on unfixed code
- [x] Failure is documented with specific counterexamples
- [x] Counterexamples confirm the bug condition from design

_Requirements: 1.1, 1.2, 2.1, 2.2_

---

## Task 2: Write Preservation Property Tests (BEFORE Implementing Fix)

- **Property 2: Preservation** - Non-Visualizer Settings Behavior
- **IMPORTANT**: Follow observation-first methodology
- **GOAL**: Capture existing behavior that must be preserved after the fix

**Observation-First Approach:**

1. Run UNFIXED code with non-buggy inputs (cases where isBugCondition returns false)
2. Observe and record actual outputs
3. fs_write property-based tests asserting those observed outputs

**Non-Buggy Inputs (where isBugCondition returns false):**
- Playback controls (play, pause, skip)
- Dialer interactions
- Other settings changes (skin type, opacity, transparency)
- UI interactions (button clicks, gestures)
- Visualizer rendering with already-persisted values

**Observed Behaviors to Preserve:**
- Playback controls continue to function correctly
- Other settings (dialer, skin, etc.) persist independently
- Visualizer renders correctly with saved values
- All UI interactions work as before

**Test Implementation:**
- Generate random non-visualizer actions
- Assert outputs match observed behavior from unfixed code
- Property-based testing generates many test cases for stronger guarantees

**Run tests on UNFIXED code:**
- **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)

**Mark task complete when:**
- [ ] Tests are written following PBT conventions
- [~] Tests are run on unfixed code
- [~] Tests pass, confirming baseline behavior
- [~] All non-visualizer behaviors are captured

_Requirements: 3.1, 3.2, 3.3, 3.4_

---

## Task 3: Implement Visualizer Persistence Fix

### Task 3.1: Add Storage Call for Visualizer Style Selection

**Location:** `lib/features/player/presentation/screens/player_screen.dart` around line 2113

**Current Code (defective):**
```dart
onTap: () {
  setState(() {
    _visualizerStyle = style;
    _visualizerVariation = 0;
  });
  // MISSING: storage.setVisualizerStyle(style.name);
  // MISSING: storage.setVisualizerVariation(0);
  Navigator.pop(context);
  _showFeedbackGlow(context, 'VISUALIZER: ${style.name.toUpperCase()}', activeSkin.textColor);
},
```

**Fixed Code:**
```dart
onTap: () {
  setState(() {
    _visualizerStyle = style;
    _visualizerVariation = 0;
  });
  // Persist the visualizer style selection
  storage.setVisualizerStyle(style.name);
  // Persist the variation reset to 0
  storage.setVisualizerVariation(0);
  Navigator.pop(context);
  _showFeedbackGlow(context, 'VISUALIZER: ${style.name.toUpperCase()}', activeSkin.textColor);
},
```

**Implementation Steps:**
1. Locate the visualizer style selection `onTap` handler (around line 2109-2113)
2. Add `storage.setVisualizerStyle(style.name);` after the setState block
3. Add `storage.setVisualizerVariation(0);` to persist the reset variation

_Bug_Condition: isBugCondition(input) where input['action'] == 'select_style' and style is not persisted_
_Expected_Behavior: expectedBehavior(result) where result.style is persisted to storage_
_Preservation: All other player settings, visualizer rendering, and UI interactions remain unchanged_
_Requirements: 2.2, 3.1, 3.3, 3.4_

---

### Task 3.2: Add Storage Call for Visualizer Variation Cycling

**Location:** `lib/features/player/presentation/screens/player_screen.dart` around line 1143

**Current Code (defective):**
```dart
setState(() {
  final int maxVars = _getMaxVariations(_visualizerStyle);
  _visualizerVariation = (_visualizerVariation + 1) % maxVars;
});
// MISSING: storage.setVisualizerVariation(_visualizerVariation);
_showFeedbackGlow(context, 'VIS VARIATION: ${_visualizerVariation + 1}', activeSkin.textColor);
```

**Fixed Code:**
```dart
setState(() {
  final int maxVars = _getMaxVariations(_visualizerStyle);
  _visualizerVariation = (_visualizerVariation + 1) % maxVars;
});
// Persist the new variation value
storage.setVisualizerVariation(_visualizerVariation);
_showFeedbackGlow(context, 'VIS VARIATION: ${_visualizerVariation + 1}', activeSkin.textColor);
```

**Implementation Steps:**
1. Locate the variation cycling code (around lines 1140-1143)
2. Add `storage.setVisualizerVariation(_visualizerVariation);` after the setState block

_Bug_Condition: isBugCondition(input) where input['action'] == 'cycle_variation' and variation is not persisted_
_Expected_Behavior: expectedBehavior(result) where result.variation is persisted to storage_
_Preservation: All other player settings, visualizer rendering, and UI interactions remain unchanged_
_Requirements: 2.2, 2.3, 3.1, 3.3, 3.4_

---

### Task 3.3: Verify Bug Condition Exploration Test Now Passes

- **Property 1: Expected Behavior** - Visualizer Persistence Works
- **IMPORTANT**: Re-run the SAME test from Task 1 - do NOT write a new test
- The test from Task 1 encodes the expected behavior
- When this test passes, it confirms the expected behavior is satisfied

**Verification Steps:**
1. Run the bug condition exploration test from Task 1
2. Verify `storage.getVisualizerStyle()` returns the selected style after selection
3. Verify `storage.getVisualizerVariation()` returns the cycled variation after cycling
4. Verify app restart restores the persisted values

**EXPECTED OUTCOME:** Test PASSES (confirms bug is fixed)

_Requirements: 2.1, 2.2, 2.3_

---

### Task 3.4: Verify Preservation Tests Still Pass

- **Property 2: Preservation** - Non-Visualizer Settings Unchanged
- **IMPORTANT**: Re-run the SAME tests from Task 2 - do NOT write new tests
- These tests capture the baseline behavior that must be preserved

**Verification Steps:**
1. Run preservation property tests from Task 2
2. Verify all non-visualizer operations produce identical results
3. Confirm no regressions in playback controls, other settings, or UI interactions

**EXPECTED OUTCOME:** Tests PASS (confirms no regressions)

_Requirements: 3.1, 3.2, 3.3, 3.4_

---

## Task 4: Checkpoint - Ensure All Tests Pass

### Final Verification Checklist

- [~] Bug condition exploration test passes (Property 1: Expected Behavior)
- [~] Preservation property tests pass (Property 2: Preservation)
- [~] Unit tests for StorageService pass
- [~] Integration tests for visualizer persistence pass
- [~] No regressions in existing functionality

### Manual Testing Steps

1. **Style Selection Persistence Test:**
   - Open the app
   - Select a visualizer style (e.g., "Waveform")
   - Close and restart the app
   - Verify the selected style is displayed

2. **Variation Cycling Persistence Test:**
   - Open the app
   - Long-press to cycle through variations
   - Note the variation number displayed
   - Close and restart the app
   - Verify the same variation is restored

3. **Combined Test:**
   - Select a style and cycle to a specific variation
   - Restart the app
   - Verify both style and variation are restored

4. **First Launch Test:**
   - Clear app data / fresh install
   - Verify default visualizer (spectrumBars, variation 0) is displayed

5. **Non-Visualizer Settings Test:**
   - Change other settings (skin, opacity, etc.)
   - Verify those settings persist correctly
   - Verify visualizer changes don't affect other settings

### Build Verification

```bash
# Run Flutter analyze to check for errors
flutter analyze

# Run tests
flutter test

# Build for testing (optional)
flutter build apk --debug
```

---

## Summary

| Task | Description | Status |
|------|-------------|--------|
| 1 | Write bug condition exploration test | Pending |
| 2 | Write preservation property tests | Pending |
| 3.1 | Add storage.setVisualizerStyle() call | Pending |
| 3.2 | Add storage.setVisualizerVariation() call | Pending |
| 3.3 | Verify bug condition test passes | Pending |
| 3.4 | Verify preservation tests pass | Pending |
| 4 | Checkpoint - all tests pass | Pending |

**Estimated Effort:** 2-3 hours
**Risk Level:** Low - Only adding two storage calls, no refactoring
**Dependencies:** None - storage service methods already exist