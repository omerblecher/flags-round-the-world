---
status: complete
phase: 05-session-polish-accessibility
source: [05-01-SUMMARY.md, 05-02-SUMMARY.md, 05-03-SUMMARY.md, 05-04-SUMMARY.md, 05-05-SUMMARY.md, 05-06-SUMMARY.md]
started: "2026-05-29T00:00:00Z"
updated: "2026-05-29T00:00:00Z"
---

## Current Test

[testing complete]

## Tests

### 1. Pause overlay
expected: Start a game. Tap the pause button (top-left of HUD). A modal overlay appears with three options — Resume, Mute toggle, End Game. Tapping Resume returns to gameplay.
result: pass

### 2. Auto-pause on background
expected: Start a game, let the timer run. Press the Home button. Return to the app. The pause overlay is showing and the timer has not advanced while backgrounded.
result: pass

### 3. Session restore — Continue dialog
expected: Start a game and place 2–3 flags. Force-quit the app (swipe away from recents). Relaunch. HomeScreen shows a "Continue your game?" dialog displaying the correct matched count and elapsed time.
result: pass

### 4. Tutorial on first launch
expected: On a fresh install (or after clearing app data), start a game. A tutorial overlay appears immediately — 4 steps with a Skip button visible from the very first frame. Tapping Skip dismisses it and starts the game.
result: pass

### 5. Mute toggle persists across restarts
expected: During a game, open the pause screen and toggle mute ON. Force-quit and relaunch. Start a new game — the mute button in the HUD should still show as muted (sound off).
result: pass

### 6. HUD touch targets are comfortable
expected: The pause button and mute button in the HUD are large enough to tap easily with a finger (≥48dp). The hint button in the flag tray is also comfortably large.
result: pass

### 7. Share Score + parental gate
expected: Complete a game. On the result screen, tap Share Score. A multiplication question appears (e.g. "43 × 7 = ?"). Entering the correct answer opens the native Android share sheet with a score card image attached.
result: pass

### 8. Wrong answer on parental gate
expected: On the result screen, tap Share Score. Enter an incorrect answer to the multiplication question. The share sheet does NOT open — the gate simply clears for another attempt.
result: pass

### 9. Privacy policy link on HomeScreen
expected: On the HomeScreen, scroll to the bottom. A "Privacy Policy" link is visible. Tapping it opens the privacy policy URL in a browser.
result: pass

### 10. Ocean colour — no black edges
expected: Start any game. Pan and zoom the map. The area outside the drawn country paths (ocean) is a consistent light blue — no black or white letterboxing visible anywhere around the edges of the map canvas.
result: pass

### 11. Correct drop — multi-modal feedback
expected: Drag a flag and drop it on the correct country. Three things happen simultaneously: the flag card animates to the country centroid (visual), a pleasant ding sound plays (audio), and a haptic pulse fires (tactile).
result: pass

### 12. Wrong drop — multi-modal feedback
expected: Drag a flag and drop it on the wrong country. Three things happen: the flag card spring-bounces back (visual), a buzzer sound plays (audio), and a haptic buzz fires (tactile). A red snackbar briefly appears.
result: pass

## Summary

total: 12
passed: 12
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
