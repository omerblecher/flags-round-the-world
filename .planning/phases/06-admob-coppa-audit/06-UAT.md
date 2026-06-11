---
status: complete
phase: 06-admob-coppa-audit
source:
  - 06-01-SUMMARY.md
  - 06-02-SUMMARY.md
  - 06-03-SUMMARY.md
  - 06-04-SUMMARY.md
started: "2026-06-11T00:00:00Z"
updated: "2026-06-11T00:00:00Z"
---

## Current Test

[testing complete]

## Tests

### 1. App Launch — No Crash
expected: Install/relaunch the app. Home screen appears — no crash, no ANR dialog, no "missing Application ID" RuntimeException.
result: pass

### 2. Banner on Home Screen
expected: On the Home screen, a test banner ad appears at the bottom of the screen. It shows the AdMob "Test Ad" label (since test ad unit IDs are active). The rest of the Home screen content (title, mode buttons, privacy footer) is not obscured by the banner.
result: pass

### 3. No Ad During Gameplay (MapScreen)
expected: Start any game mode. On the map screen during active gameplay, there is NO banner ad strip anywhere — the full screen is used for the map + flag tray. No ad of any kind interrupts gameplay.
result: pass

### 4. No Ad on Pause Screen
expected: During a game, pause it (back button or pause button). The pause screen shows — there is NO banner, interstitial, or any other ad on the pause screen.
result: pass

### 5. Interstitial on Game Complete
expected: Complete a full round of any game mode (place the last flag). As the completion screen loads, an interstitial test ad appears (full-screen overlay with "Test Ad"). Dismissing it reveals the Completion screen.
result: pass

### 6. Banner on Completion Screen
expected: After dismissing the interstitial (or if it doesn't appear — test environment can vary), the Completion screen shows a test banner at the bottom. The score, star rating, and action buttons are visible above it.
result: pass

### 7. Rewarded Ad on Hint Exhausted
expected: During a game, use all available hints (tap hint button until none remain). Tap the hint button again when exhausted. A rewarded test ad is offered. Watch it to completion — hints are refilled (2 restored). Dismissing without watching gives no hints.
result: pass

### 8. App Open Ad on Resume
expected: From the Home screen, background the app (home button), wait ~2 seconds, then bring it back to the foreground. An App Open test ad appears. Dismissing it returns to the Home screen normally.
result: pass

### 9. App Open Suppressed During Gameplay
expected: Start a game and get to active gameplay. Background the app (home button), wait ~2 seconds, bring it back. NO App Open ad appears — the game resumes directly. The suppression works because gameplay phase blocks the App Open trigger.
result: pass

## Summary

total: 9
passed: 9
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
