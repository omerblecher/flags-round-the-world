import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:flags_around_the_world/core/ads/ad_load_state.dart';
import 'package:flags_around_the_world/core/ads/ad_service_provider.dart';
import 'package:flags_around_the_world/core/audio/audio_service_provider.dart';
import 'package:flags_around_the_world/core/data/country_data_service.dart';
import 'package:flags_around_the_world/core/data/high_score_repository.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';
import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';
import 'package:flags_around_the_world/features/game/game_mode.dart';
import 'package:flags_around_the_world/features/game/game_phase.dart';
import 'package:flags_around_the_world/features/game/game_hud.dart';
import 'package:flags_around_the_world/features/map/world_map_painter.dart';
import 'package:flags_around_the_world/features/map/highlight_painter.dart';
import 'package:flags_around_the_world/features/map/hit_detection.dart';
import 'package:flags_around_the_world/features/game/flag_tray.dart';
import 'package:flags_around_the_world/features/game/game_session_notifier.dart';
import 'package:flags_around_the_world/features/map/flag_sequence.dart';

// Top-level provider — no codegen per project convention.
final countryDataProvider = FutureProvider<List<CountryData>>(
  (ref) => CountryDataService().loadMapData(),
);

class MapScreen extends ConsumerStatefulWidget {
  final GameMode mode;

  const MapScreen({super.key, required this.mode});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  final GlobalKey _ivKey = GlobalKey();

  String? _hoveredIso;
  Map<String, CountryData> _countryIndex = {};
  List<CountryData> _countries = [];

  // ---------- Flag sequence state (Plan 03-04) --------------------------------

  String _currentIsoCode = '';
  List<String> _remainingIsoCodes = [];
  // Not 'final' — replaced with a new Set on each advance so shouldRepaint
  // receives distinct object references and can detect the change.
  Set<String> _matchedIsoCodes = {};
  bool _sequenceInitialized = false;

  // ---------- Tray keys -------------------------------------------------------

  // Re-created each time we advance to a new flag so AnimatedSwitcher animates.
  GlobalKey<FlagTrayState> _trayKey = GlobalKey<FlagTrayState>();
  // Must be a new instance on every advance: AnimatedSwitcher mounts old and
  // new FlagTray simultaneously, so sharing a GlobalKey throws.
  GlobalKey _trayCardKey = GlobalKey();

  // ---------- Overlay animation -----------------------------------------------

  OverlayEntry? _activeOverlay;

  // ---------- Current viewport scale (for scale-adaptive HighlightPainter) ---

  double _currentScale = 1.0;

  // ---------- Hint state (Plan 04-04) -----------------------------------------

  String? _hintIso;
  Timer? _hintTimer;
  late AnimationController _hintZoomController;
  Animation<Matrix4>? _hintZoomAnim;

  // --------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScaleChanged);
    _hintZoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  void _onScaleChanged() {
    final s = _controller.value.entry(0, 0);
    if ((s - _currentScale).abs() > 0.005) {
      setState(() => _currentScale = s);
    }
  }

  @override
  void dispose() {
    _hintZoomController.dispose();
    _hintTimer?.cancel();
    _controller.removeListener(_onScaleChanged);
    _activeOverlay?.remove();
    _activeOverlay = null;
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sequence initialisation — called once when country data arrives.
  // ---------------------------------------------------------------------------

  void _initSequence(List<CountryData> countries) {
    if (_sequenceInitialized) return;
    _sequenceInitialized = true;
    if (widget.mode == GameMode.grandMaster) {
      buildGrandMasterSequence(countries).then((seq) {
        if (!mounted) return;
        setState(() {
          _remainingIsoCodes = seq;
          if (_remainingIsoCodes.isNotEmpty) _currentIsoCode = _remainingIsoCodes.first;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapToScreen();
          ref.read(gameSessionProvider.notifier).startGame(widget.mode);
        });
      });
    } else {
      _remainingIsoCodes = buildFlagSequence(countries);
      if (_remainingIsoCodes.isNotEmpty) _currentIsoCode = _remainingIsoCodes.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapToScreen();
        ref.read(gameSessionProvider.notifier).startGame(widget.mode);
      });
    }
  }

  void _fitMapToScreen() {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    const mapW = 2000.0;
    const mapH = 1000.0;
    final scale = math.min(box.size.width / mapW, box.size.height / mapH)
        .clamp(0.08, 1.0);
    final tx = (box.size.width - mapW * scale) / 2;
    final ty = (box.size.height - mapH * scale) / 2;
    final m = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    _controller.value = m;
  }

  // ---------------------------------------------------------------------------
  // Hint handling (Plan 04-04)
  // ---------------------------------------------------------------------------

  void _useHint() {
    final session = ref.read(gameSessionProvider).value;
    if (session == null || session.phase != GamePhase.playing) return;

    if (session.hintsRemaining <= 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(AppLocalizations.of(context).hintOutTitle),
          content: Text(AppLocalizations.of(context).hintOutMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).hintCancel),
            ),
            TextButton(
              onPressed: () async {
                // Capture messenger and l10n before popping — dialog context
                // becomes detached after Navigator.pop and cannot be used for
                // ScaffoldMessenger lookup.
                final messenger = ScaffoldMessenger.of(context);
                final failMsg = AppLocalizations.of(context).hintAdFailed;
                Navigator.pop(context);
                final adResult = await ref.read(adServiceProvider).loadRewardedAd();
                if (adResult is AdLoaded) {
                  // Phase 6 will add refillHints() to GameSessionNotifier.
                } else {
                  if (mounted) {
                    messenger.showSnackBar(SnackBar(content: Text(failMsg)));
                  }
                }
              },
              child: Text(AppLocalizations.of(context).hintWatchAd),
            ),
          ],
        ),
      );
      return;
    }

    final used = ref.read(gameSessionProvider.notifier).useHint();
    if (!used) return;

    final l10n = AppLocalizations.of(context);
    final countryNamesAsync = ref.read(countryNamesProvider);
    final name = countryNamesAsync.value?[_currentIsoCode] ?? _currentIsoCode;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.hintLocating(name)),
      duration: const Duration(milliseconds: 1800),
    ));

    setState(() => _hintIso = _currentIsoCode);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hintIso = null);
    });

    final country = _countryIndex[_currentIsoCode];
    if (country != null) _animateHintZoom(country.centroid);
  }

  void _animateHintZoom(Offset sceneCentroid) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    const targetScale = 3.0;
    final tx = box.size.width / 2 - sceneCentroid.dx * targetScale;
    final ty = box.size.height / 2 - sceneCentroid.dy * targetScale;
    final targetMatrix = Matrix4.identity()
      ..setEntry(0, 0, targetScale)
      ..setEntry(1, 1, targetScale)
      ..setEntry(2, 2, targetScale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
    _hintZoomAnim?.removeListener(_applyHintZoom);
    _hintZoomAnim = Matrix4Tween(
      begin: _controller.value.clone(),
      end: targetMatrix,
    ).animate(CurvedAnimation(parent: _hintZoomController, curve: Curves.easeInOut));
    _hintZoomAnim!.addListener(_applyHintZoom);
    _hintZoomController
      ..reset()
      ..forward().whenComplete(() => _hintZoomAnim?.removeListener(_applyHintZoom));
  }

  void _applyHintZoom() {
    if (_hintZoomAnim != null) _controller.value = _hintZoomAnim!.value;
  }

  // ---------------------------------------------------------------------------
  // Advance to the next flag after a correct drop.
  // ---------------------------------------------------------------------------

  Future<void> _advanceToNextFlag() async {
    if (_remainingIsoCodes.isEmpty) return;
    setState(() {
      // Spread into a new Set so WorldMapPainter.shouldRepaint receives distinct
      // object references and correctly triggers a repaint.
      _matchedIsoCodes = {..._matchedIsoCodes, _currentIsoCode};
      _remainingIsoCodes.removeAt(0);
    });
    if (_remainingIsoCodes.isEmpty) {
      // All flags placed — complete the game and navigate to result screen.
      final sessionBeforeComplete = ref.read(gameSessionProvider).value!;
      final repo = await ref.read(highScoreRepositoryProvider.future);
      final previousBest = await repo.getBestScore(sessionBeforeComplete.mode);
      await ref.read(gameSessionProvider.notifier).completeGame();
      // completeGame() already calls saveBestScore — no redundant save here.
      if (!mounted) return;
      final completedSession = ref.read(gameSessionProvider).value;
      if (completedSession == null) return;
      context.go('/result', extra: {
        'session': completedSession,
        'previousBest': previousBest,
      });
    } else {
      setState(() {
        _currentIsoCode = _remainingIsoCodes.first;
        // New GlobalKey instances → AnimatedSwitcher detects widget change.
        _trayKey = GlobalKey<FlagTrayState>();
        _trayCardKey = GlobalKey();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Zoom helpers — viewport-centre-anchored to prevent drift (from spike).
  // ---------------------------------------------------------------------------

  void _zoom(double factor) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final double cx = box.size.width / 2;
    final double cy = box.size.height / 2;

    final Matrix4 m = _controller.value.clone();
    final double currentScale = m.getMaxScaleOnAxis();
    final double newScale = (currentScale * factor).clamp(0.08, 32.0);
    final double actualFactor = newScale / currentScale;
    if ((actualFactor - 1.0).abs() < 1e-6) return;

    final double tx = m.entry(0, 3);
    final double ty = m.entry(1, 3);
    m.setEntry(0, 0, newScale);
    m.setEntry(1, 1, newScale);
    // (2,2) must stay in sync with (0,0)/(1,1) so getMaxScaleOnAxis() returns
    // the correct 2-D scale instead of 1.0 (the untouched Z-axis default).
    // Without this, zooming out below 1.0 then pressing "+" causes a wild jump.
    m.setEntry(2, 2, newScale);
    m.setEntry(0, 3, cx + (tx - cx) * actualFactor);
    m.setEntry(1, 3, cy + (ty - cy) * actualFactor);
    _controller.value = m;
  }

  void _zoomIn()  => _zoom(1.5);
  void _zoomOut() => _zoom(1 / 1.5);

  // ---------------------------------------------------------------------------
  // Coordinate transform helpers.
  // ---------------------------------------------------------------------------

  Offset? _toSceneFromGlobal(Offset globalOffset) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return _controller.toScene(box.globalToLocal(globalOffset));
  }

  /// Converts a scene-space centroid (InteractiveViewer child coords) to global
  /// screen coordinates.
  Offset _centroidToScreen(Offset sceneCentroid) {
    final matrix = _controller.value;
    final viewportLocal = MatrixUtils.transformPoint(matrix, sceneCentroid);
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(viewportLocal);
  }

  // ---------------------------------------------------------------------------
  // Correct-drop fly-to-centroid animation.
  // ---------------------------------------------------------------------------

  void _animateCorrectDrop(String isoCode, {double copyOffsetX = 0}) {
    // Get start position from the tray card.
    final trayBox =
        _trayCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (trayBox == null) {
      _advanceToNextFlag();
      return;
    }
    final startOffset = trayBox.localToGlobal(Offset.zero);

    // Get end position (country centroid in screen coords).
    // Use copyOffsetX so the animation flies to the copy the user dropped on,
    // not back to the canonical (possibly off-screen) copy.
    final country = _countryIndex[isoCode];
    if (country == null) {
      _advanceToNextFlag();
      return;
    }
    final sceneCentroid =
        Offset(country.centroid.dx + copyOffsetX, country.centroid.dy);
    final endOffset = _centroidToScreen(sceneCentroid);

    final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final posAnim = Tween<Offset>(begin: startOffset, end: endOffset).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeInOut),
    );
    final scaleAnim = Tween<double>(begin: 1.0, end: 0.15).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeInOut),
    );
    final opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: animController, curve: Curves.easeInOut),
    );

    _activeOverlay?.remove();
    _activeOverlay = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: animController,
        builder: (ctx, child) => Positioned(
          left: posAnim.value.dx,
          top: posAnim.value.dy,
          child: Opacity(
            opacity: opacityAnim.value,
            child: Transform.scale(scale: scaleAnim.value, child: child),
          ),
        ),
        child: SizedBox(
          width: 90,
          height: 60,
          child: SvgPicture.asset(
            'assets/flags/${isoCode.toLowerCase()}.svg',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_activeOverlay!);

    animController.forward().whenComplete(() {
      _activeOverlay?.remove();
      _activeOverlay = null;
      animController.dispose();
      _advanceToNextFlag();
    });
  }

  // ---------------------------------------------------------------------------
  // Drop handler — correct and incorrect paths.
  // ---------------------------------------------------------------------------

  void _handleDrop(String? hitIso, bool isCorrect, {double copyOffsetX = 0}) {
    if (isCorrect && hitIso != null) {
      ref
          .read(gameSessionProvider.notifier)
          .recordDrop(hitIso, isCorrect: true);
      HapticFeedback.lightImpact();
      ref.read(audioServiceProvider).playCorrect();
      setState(() => _hoveredIso = null);
      _animateCorrectDrop(hitIso, copyOffsetX: copyOffsetX);
    } else {
      ref.read(gameSessionProvider.notifier).recordDrop(
            hitIso ?? _currentIsoCode,
            isCorrect: false,
          );
      HapticFeedback.mediumImpact();
      ref.read(audioServiceProvider).playError();
      // triggerBounce must be called before setState invalidates _trayKey.
      _trayKey.currentState?.triggerBounce();
      setState(() => _hoveredIso = null);
    }
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  Widget _buildMap(List<CountryData> countries) {
    // Populate index and list once when data arrives; init flag sequence.
    if (_countryIndex.isEmpty && countries.isNotEmpty) {
      _countryIndex = {for (final c in countries) c.isoCode: c};
      _countries = countries;
    }
    _initSequence(countries);

    final l10n = AppLocalizations.of(context);
    final session = ref.watch(gameSessionProvider).value;
    final hintsRemaining = session?.hintsRemaining ?? 2;
    final countryNamesAsync = ref.watch(countryNamesProvider);
    final countryNames = countryNamesAsync.value ?? {};
    final matchedCount = _matchedIsoCodes.length;
    const totalFlags = 196;

    // Mode-based visibility booleans (per D-A04).
    final showLabels = widget.mode == GameMode.learn ||
        widget.mode == GameMode.geographicalMaster;
    final showName = widget.mode == GameMode.learn ||
        widget.mode == GameMode.flagsMaster;

    return Column(
      children: [
        // HUD strip — always visible above the map.
        GameHud(
          score: session?.score ?? 0,
          elapsed: session?.elapsed ?? Duration.zero,
          matchedCount: matchedCount,
          totalFlags: totalFlags,
        ),
        // Map area
        Expanded(
          child: Stack(
            children: [
              // InteractiveViewer
              InteractiveViewer(
                key: _ivKey,
                transformationController: _controller,
                constrained: false,
                minScale: 0.08,
                maxScale: 32.0,
                child: SizedBox(
                  // Double width so the world wraps: after Australia the user
                  // can keep panning right to reach the Americas.
                  width: 4000,
                  height: 1000,
                  child: Stack(
                    children: [
                      // Layer 1: static map (fills, borders, labels)
                      RepaintBoundary(
                        child: CustomPaint(
                          isComplex: true,
                          painter: WorldMapPainter(
                            countries: countries,
                            matchedIsoCodes: _matchedIsoCodes,
                            showLabels: showLabels,
                            countryNames: countryNames,
                          ),
                          size: const Size(4000, 1000),
                        ),
                      ),
                      // Layer 2: dynamic hover highlight + target indicator + hint
                      RepaintBoundary(
                        child: CustomPaint(
                          willChange: true,
                          painter: HighlightPainter(
                            hoveredIso: _hoveredIso,
                            countryIndex: _countryIndex,
                            targetIsoCode: _currentIsoCode.isEmpty
                                ? null
                                : _currentIsoCode,
                            viewScale: _currentScale,
                            hintIso: _hintIso,
                          ),
                          size: const Size(4000, 1000),
                        ),
                      ),
                      // Layer 3: DragTarget — receives flags dragged over the map.
                      DragTarget<String>(
                        builder: (ctx, _, __) => const SizedBox.expand(),
                        onWillAcceptWithDetails: (details) {
                          // details.offset = pointer − FlagTray.kPinAnchor;
                          // add the anchor back to get the actual pin-tip position.
                          final rawScene = _toSceneFromGlobal(
                              details.offset + FlagTray.kPinAnchor);
                          if (rawScene == null) return true;
                          // Normalise to canonical 0-2000 range so hit detection
                          // works identically on the wrapped right copy.
                          final scenePoint =
                              Offset(rawScene.dx % 2000, rawScene.dy);
                          final scale =
                              _controller.value.getMaxScaleOnAxis();
                          final hitIso = hitTest(
                            scenePoint,
                            _countries,
                            scale: scale,
                          );
                          // Only glow the current target country during hover.
                          // Highlighting non-target countries (e.g. Venezuela
                          // while dragging Grenada through its territory) is
                          // confusing — the gold colour should mean "right place."
                          setState(() => _hoveredIso =
                              hitIso == _currentIsoCode ? hitIso : null);
                          return true;
                        },
                        onAcceptWithDetails: (details) {
                          final rawScene = _toSceneFromGlobal(
                              details.offset + FlagTray.kPinAnchor);
                          if (rawScene == null) return;
                          // Which world copy the pin landed in (0 = canonical,
                          // 2000 = right copy, etc.).  Used to fly the animation
                          // to the correct on-screen position.
                          final copyOffsetX =
                              (rawScene.dx / 2000).floor() * 2000.0;
                          final scenePoint =
                              Offset(rawScene.dx % 2000, rawScene.dy);
                          final scale =
                              _controller.value.getMaxScaleOnAxis();
                          final hitIso = hitTest(
                            scenePoint,
                            _countries,
                            scale: scale,
                          );
                          final isCorrect = hitIso == _currentIsoCode;
                          _handleDrop(hitIso, isCorrect,
                              copyOffsetX: copyOffsetX);
                        },
                        onLeave: (_) => setState(() => _hoveredIso = null),
                      ),
                    ],
                  ),
                ),
              ),
              // Zoom buttons — outside IV so they stay fixed on screen.
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      onPressed: _zoomIn,
                      tooltip: l10n.zoomInTooltip,
                      heroTag: 'map_zoom_in',
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      onPressed: _zoomOut,
                      tooltip: l10n.zoomOutTooltip,
                      heroTag: 'map_zoom_out',
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Flag tray — slides in when the current ISO code changes.
        // _trayKey is re-created on each advance so AnimatedSwitcher detects
        // the widget change and plays the slide-in transition.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          // FadeTransition keeps the widget at its laid-out position so its
          // hit-test area is valid throughout the transition. SlideTransition
          // moves the hit-test area with the animation, making the Draggable
          // unreachable during the 300 ms slide-in window (Bug 1 root cause).
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _currentIsoCode.isEmpty
              ? const SizedBox.shrink()
              : FlagTray(
                  key: _trayKey,
                  currentIsoCode: _currentIsoCode,
                  countryName: countryNames[_currentIsoCode] ?? _currentIsoCode,
                  cardKey: _trayCardKey,
                  showName: showName,
                  hintsRemaining: hintsRemaining,
                  onHintPressed: _useHint,
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n    = AppLocalizations.of(context);
    final mapData = ref.watch(countryDataProvider);

    return mapData.when(
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.loadingMap),
          ],
        ),
      ),
      error: (_, __) => Center(child: Text(l10n.mapLoadError)),
      data: _buildMap,
    );
  }
}
