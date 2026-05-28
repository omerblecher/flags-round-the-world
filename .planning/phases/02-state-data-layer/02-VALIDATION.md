---
phase: 2
slug: 02-state-data-layer
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-28
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (Flutter SDK 3.44.0) |
| **Config file** | none — standard `flutter test` discovery |
| **Quick run command** | `flutter test test/unit/ test/architecture/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/unit/ test/architecture/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| GameSession model | 02-01 | 1 | — | — | N/A | unit | `flutter test test/unit/game_session_notifier_test.dart` | ❌ W0 | ⬜ pending |
| Ticker abstraction | 02-01 | 1 | — | — | N/A | unit | `flutter test test/unit/game_session_notifier_test.dart` | ❌ W0 | ⬜ pending |
| GameSessionNotifier | 02-02 | 2 | SCOR-01, SCOR-02 | — | No features/ads/ imports | unit + arch | `flutter test test/unit/game_session_notifier_test.dart test/architecture/ads_isolation_test.dart` | ❌ W0 | ⬜ pending |
| HighScoreRepository | 02-03 | 3 | SCOR-04 | — | N/A | unit | `flutter test test/unit/high_score_repository_test.dart` | ❌ W0 | ⬜ pending |
| GameStateRepository | 02-03 | 3 | — | — | N/A | unit | `flutter test test/unit/game_state_repository_test.dart` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/unit/game_session_notifier_test.dart` — stubs for SC1, SC2, SCOR-01, SCOR-02
- [ ] `test/unit/high_score_repository_test.dart` — stubs for SC3, SCOR-04
- [ ] `test/unit/game_state_repository_test.dart` — stubs for SC4 (SESS-03 write path)

*Existing infrastructure: `flutter_test` SDK, `mocktail ^1.0.5`, `shared_preferences ^2.5.5` mock helper — all available in pubspec.yaml. No new framework setup needed.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
