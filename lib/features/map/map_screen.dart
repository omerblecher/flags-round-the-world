import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flags_around_the_world/core/audio/audio_service_provider.dart';
import 'package:flags_around_the_world/core/data/country_data_service.dart';
import 'package:flags_around_the_world/core/models/country_data.dart';
import 'package:flags_around_the_world/generated/l10n/app_localizations.dart';
import 'package:flags_around_the_world/features/map/world_map_painter.dart';
import 'package:flags_around_the_world/features/map/highlight_painter.dart';
import 'package:flags_around_the_world/features/map/hit_detection.dart';
import 'package:flags_around_the_world/features/map/completion_screen.dart';
import 'package:flags_around_the_world/features/game/flag_tray.dart';
import 'package:flags_around_the_world/features/game/game_session_notifier.dart';

// Top-level provider — no codegen per project convention.
final countryDataProvider = FutureProvider<List<CountryData>>(
  (ref) => CountryDataService().loadMapData(),
);

/// Builds a shuffled list of ISO codes from [countries].
/// Exposed as a top-level function for unit testing.
List<String> buildFlagSequence(List<CountryData> countries) {
  final list = countries.map((c) => c.isoCode).toList();
  list.shuffle();
  return list;
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

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
  final Set<String> _matchedIsoCodes = {};
  bool _sequenceInitialized = false;

  // ---------- Tray keys -------------------------------------------------------

  // Re-created each time we advance to a new flag so AnimatedSwitcher animates.
  GlobalKey<FlagTrayState> _trayKey = GlobalKey<FlagTrayState>();
  final GlobalKey _trayCardKey = GlobalKey();

  // ---------- Overlay animation -----------------------------------------------

  OverlayEntry? _activeOverlay;

  // --------------------------------------------------------------------------

  @override
  void dispose() {
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
    _remainingIsoCodes = buildFlagSequence(countries);
    if (_remainingIsoCodes.isNotEmpty) {
      _currentIsoCode = _remainingIsoCodes.first;
    }
  }

  // ---------------------------------------------------------------------------
  // Advance to the next flag after a correct drop.
  // ---------------------------------------------------------------------------

  Future<void> _advanceToNextFlag() async {
    if (_remainingIsoCodes.isEmpty) return;
    setState(() {
      _matchedIsoCodes.add(_currentIsoCode);
      _remainingIsoCodes.removeAt(0);
    });
    if (_remainingIsoCodes.isEmpty) {
      // All flags placed — complete the game.
      await ref.read(gameSessionProvider.notifier).completeGame();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompletionScreen(
              session: ref.read(gameSessionProvider).value!,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _currentIsoCode = _remainingIsoCodes.first;
        // New GlobalKey instance → AnimatedSwitcher detects change and animates.
        _trayKey = GlobalKey<FlagTrayState>();
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
    final double newScale = (currentScale * factor).clamp(0.08, 8.0);
    final double actualFactor = newScale / currentScale;
    if ((actualFactor - 1.0).abs() < 1e-6) return;

    final double tx = m.entry(0, 3);
    final double ty = m.entry(1, 3);
    m.setEntry(0, 0, newScale);
    m.setEntry(1, 1, newScale);
    m.setEntry(0, 3, cx + (tx - cx) * actualFactor);
    m.setEntry(1, 3, cy + (ty - cy) * actualFactor);
    _controller.value = m;
  }

  void _zoomIn()  => _zoom(1.5);
  void _zoomOut() => _zoom(1 / 1.5);

  // ---------------------------------------------------------------------------
  // Coordinate transform helpers.
  // ---------------------------------------------------------------------------

  Offset _toSceneFromGlobal(Offset globalOffset) {
    final box = _ivKey.currentContext!.findRenderObject() as RenderBox;
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

  void _animateCorrectDrop(String isoCode) {
    // Get start position from the tray card.
    final trayBox =
        _trayCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (trayBox == null) {
      _advanceToNextFlag();
      return;
    }
    final startOffset = trayBox.localToGlobal(Offset.zero);

    // Get end position (country centroid in screen coords).
    final country = _countryIndex[isoCode];
    if (country == null) {
      _advanceToNextFlag();
      return;
    }
    final endOffset = _centroidToScreen(country.centroid);

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

  void _handleDrop(String? hitIso, bool isCorrect) {
    if (isCorrect && hitIso != null) {
      ref
          .read(gameSessionProvider.notifier)
          .recordDrop(hitIso, isCorrect: true);
      HapticFeedback.lightImpact();
      ref.read(audioServiceProvider).playCorrect();
      setState(() => _hoveredIso = null);
      _animateCorrectDrop(hitIso);
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
  // Country name helper — real localised name wired in Phase 4.
  // ---------------------------------------------------------------------------

  String _countryName(String isoCode) => isoCode.toUpperCase();

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

    return Column(
      children: [
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
                maxScale: 8.0,
                child: SizedBox(
                  width: 2000,
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
                          ),
                          size: const Size(2000, 1000),
                        ),
                      ),
                      // Layer 2: dynamic hover highlight
                      RepaintBoundary(
                        child: CustomPaint(
                          willChange: true,
                          painter: HighlightPainter(
                            hoveredIso: _hoveredIso,
                            countryIndex: _countryIndex,
                          ),
                          size: const Size(2000, 1000),
                        ),
                      ),
                      // Layer 3: DragTarget — receives flags dragged over the map.
                      DragTarget<String>(
                        builder: (ctx, _, __) => const SizedBox.expand(),
                        onWillAcceptWithDetails: (details) {
                          final scenePoint =
                              _toSceneFromGlobal(details.offset);
                          final hitIso = hitTest(scenePoint, _countries);
                          setState(() => _hoveredIso = hitIso);
                          return true;
                        },
                        onAcceptWithDetails: (details) {
                          final scenePoint =
                              _toSceneFromGlobal(details.offset);
                          final hitIso = hitTest(scenePoint, _countries);
                          final isCorrect = hitIso == _currentIsoCode;
                          _handleDrop(hitIso, isCorrect);
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
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
          child: _currentIsoCode.isEmpty
              ? const SizedBox.shrink()
              : FlagTray(
                  key: _trayKey,
                  currentIsoCode: _currentIsoCode,
                  countryName: _countryName(_currentIsoCode),
                  cardKey: _trayCardKey,
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
