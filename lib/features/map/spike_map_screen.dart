import 'package:flutter/material.dart';

class SpikeMapScreen extends StatefulWidget {
  const SpikeMapScreen({super.key});

  @override
  State<SpikeMapScreen> createState() => _SpikeMapScreenState();
}

class _SpikeMapScreenState extends State<SpikeMapScreen> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _ivKey = GlobalKey();

  // 5 labeled regions at known scene coordinates
  static final _regions = [
    _Region('Region A', const Rect.fromLTWH(100, 100, 200, 150)),
    _Region('Region B', const Rect.fromLTWH(400, 300, 150, 120)),
    _Region('Region C', const Rect.fromLTWH(800, 200, 180, 160)),
    _Region('Region D', const Rect.fromLTWH(1200, 400, 140, 130)),
    _Region('Region E', const Rect.fromLTWH(1600, 600, 160, 140)),
  ];

  static const _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _toSceneFromGlobal(Offset globalOffset) {
    final box = _ivKey.currentContext!.findRenderObject()! as RenderBox;
    return _controller.toScene(box.globalToLocal(globalOffset));
  }

  String? _hitTest(Offset scenePoint) {
    for (final region in _regions) {
      if (region.rect.contains(scenePoint)) return region.name;
    }
    return null;
  }

  void _zoom(double factor) {
    final box = _ivKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final double cx = box.size.width / 2;
    final double cy = box.size.height / 2;

    final Matrix4 m = _controller.value.clone();
    final double currentScale = m.getMaxScaleOnAxis();
    final double newScale = (currentScale * factor).clamp(0.1, 10.0);
    final double actualFactor = newScale / currentScale;
    if ((actualFactor - 1.0).abs() < 1e-6) return;

    // Keep the viewport center fixed: new_tx = cx + (tx - cx) * actualFactor
    final double tx = m.entry(0, 3);
    final double ty = m.entry(1, 3);
    m.setEntry(0, 0, newScale);
    m.setEntry(1, 1, newScale);
    m.setEntry(0, 3, cx + (tx - cx) * actualFactor);
    m.setEntry(1, 3, cy + (ty - cy) * actualFactor);
    _controller.value = m;
  }

  void _zoomIn() => _zoom(1.5);
  void _zoomOut() => _zoom(1 / 1.5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coordinate Transform Spike')),
      body: Stack(
        children: [
          InteractiveViewer(
            key: _ivKey,
            transformationController: _controller,
            constrained: false,
            minScale: 0.1,
            maxScale: 10.0,
            child: SizedBox(
              width: 2000,
              height: 1000,
              child: Stack(
                children: [
                  Container(color: const Color(0xFFA8D5E8)),
                  for (int i = 0; i < _regions.length; i++)
                    Positioned(
                      left: _regions[i].rect.left,
                      top: _regions[i].rect.top,
                      width: _regions[i].rect.width,
                      height: _regions[i].rect.height,
                      child: Container(
                        color: _colors[i].withValues(alpha: 0.7),
                        child: Center(
                          child: Text(
                            _regions[i].name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  DragTarget<String>(
                    builder: (ctx, _, __) => const SizedBox.expand(),
                    onAcceptWithDetails: (details) {
                      final scenePoint = _toSceneFromGlobal(details.offset);
                      final hit = _hitTest(scenePoint);
                      final zoom =
                          _controller.value.getMaxScaleOnAxis().toStringAsFixed(2);
                      debugPrint(
                        'Hit: $hit at scene=$scenePoint zoom=${zoom}x',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Draggable source — outside InteractiveViewer in the Stack
          Positioned(
            top: 16,
            left: 16,
            child: Draggable<String>(
              data: 'test',
              feedback: Material(
                child: Container(
                  width: 60,
                  height: 40,
                  color: Colors.yellow,
                  child: const Center(child: Text('Drag me')),
                ),
              ),
              child: Container(
                width: 60,
                height: 40,
                color: Colors.yellow,
                child: const Center(child: Text('Drag me')),
              ),
            ),
          ),
          // Zoom buttons
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: _zoomIn,
                  tooltip: 'Zoom in',
                  heroTag: 'zoom_in',
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  onPressed: _zoomOut,
                  tooltip: 'Zoom out',
                  heroTag: 'zoom_out',
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Region {
  final String name;
  final Rect rect;
  const _Region(this.name, this.rect);
}
