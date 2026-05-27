import 'dart:ui';
import 'package:path_drawing/path_drawing.dart';

class BoundingBox {
  final double x, y, w, h;
  const BoundingBox({required this.x, required this.y, required this.w, required this.h});
  Rect get rect => Rect.fromLTWH(x, y, w, h);
  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    w: (json['w'] as num).toDouble(),
    h: (json['h'] as num).toDouble(),
  );
}

class CountryData {
  final String isoCode;
  final List<String> pathStrings;
  final List<Path> paths;
  final BoundingBox boundingBox;
  final Offset centroid;

  const CountryData({
    required this.isoCode,
    required this.pathStrings,
    required this.paths,
    required this.boundingBox,
    required this.centroid,
  });

  factory CountryData.fromJson(Map<String, dynamic> json) {
    final pathStrings = List<String>.from(json['paths'] as List);
    final paths = pathStrings.map((s) => parseSvgPathData(s)).toList();
    final bb = BoundingBox.fromJson(json['boundingBox'] as Map<String, dynamic>);
    final c = json['centroid'] as Map<String, dynamic>;
    return CountryData(
      isoCode: json['iso'] as String,
      pathStrings: pathStrings,
      paths: paths,
      boundingBox: bb,
      centroid: Offset((c['x'] as num).toDouble(), (c['y'] as num).toDouble()),
    );
  }
}
