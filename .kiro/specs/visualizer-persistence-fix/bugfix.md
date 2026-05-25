# Bugfix Requirements Document

## Introduction

The UltraMP3 Reborn music player app fails to persist the user's visualizer selection between app launches. When the app is restarted, the visualizer reverts to the first available style instead of restoring the user's previously selected visualizer. This affects user experience as users must repeatedly reselect their preferred visualizer style after each app restart.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the user launches the app THEN the system displays the first visualizer in the list regardless of the previously selected visualizer
1.2 WHEN the user selects a visualizer and restarts the app THEN the system loses the visualizer selection and defaults to visualizer index 0

### Expected Behavior (Correct)

2.1 WHEN the user launches the app THEN the system SHALL retrieve the saved visualizer index from Hive storage and display the corresponding visualizer
2.2 WHEN the user selects a visualizer THEN the system SHALL persist the selected visualizer index to Hive storage immediately
2.3 WHEN the user restarts the app THEN the system SHALL restore the last selected visualizer and display it to the user

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user changes the visualizer while the app is running THEN the system SHALL CONTINUE TO update the visualizer display in real-time
3.2 WHEN the user has not selected any visualizer before (first launch) THEN the system SHALL CONTINUE TO display the default visualizer (index 0)
3.3 WHEN the user changes other settings (equalizer, playback, etc.) THEN the system SHALL CONTINUE TO persist those settings independently
3.4 WHEN the app is running THEN the system SHALL CONTINUE TO support all 21 visualizer styles with their variations

## Bug Condition Derivation

### Bug Condition Function

```pascal
FUNCTION isBugCondition(appState)
  INPUT: appState of type AppLaunchState
  OUTPUT: boolean

  // Returns true when the bug condition is met (no persisted visualizer on app launch)
  RETURN appState.isAppLaunch AND appState.savedVisualizerIndex = null
END FUNCTION
```

### Property Specification

```pascal
// Property: Fix Checking - Visualizer Persistence
FOR ALL appState WHERE isBugCondition(appState) DO
  result ← initializeVisualizer'(appState)
  ASSERT result.visualizerIndex = appState.savedVisualizerIndex
  ASSERT result.displayedVisualizer = getVisualizer(appState.savedVisualizerIndex)
END FOR

// Property: Preservation Checking
FOR ALL appState WHERE NOT isBugCondition(appState) DO
  result ← initializeVisualizer'(appState)
  originalResult ← initializeVisualizer(appState)
  ASSERT result.visualizerIndex = originalResult.visualizerIndex
END FOR
```

## Root Cause Hypothesis

Based on the bug description and typical Flutter/Hive implementation patterns, the issue likely exists in one of the following locations:

1. **StorageService**: The Hive box for visualizer settings may not be properly initialized, or the `saveVisualizer` and `getVisualizer` methods may be missing or incorrectly implemented.

2. **PlayerScreen/VisualizerProvider**: The provider or state management class may not be calling the storage service on app initialization, or may be overwriting the restored value with the default.

3. **Initialization Order**: The visualizer selection may be loaded after the UI has already initialized with the default value, causing a race condition.

## Clarifying Questions

The following questions would help clarify the bug and ensure complete requirements:

1. Is there existing code for saving/loading visualizer selection, or is this a completely missing feature?
2. What is the exact key name used (or should be used) for storing the visualizer index in Hive?
3. Are there any error logs or crash reports when the persistence fails?
4. Does the issue occur on both Android and iOS platforms, or is it platform-specific?
5. Is there a specific visualizer index that should be the default (e.g., index 0)?

## Acceptance Criteria

1. The visualizer selection SHALL be saved to Hive immediately when the user changes it
2. The visualizer selection SHALL be restored from Hive on app launch
3. The app SHALL display the correct visualizer on startup without requiring user intervention
4. First-time users SHALL see the default visualizer (index 0)
5. Other app settings SHALL continue to work independently of visualizer persistence