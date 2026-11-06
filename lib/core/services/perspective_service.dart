import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Represents 4 corners of a quadrilateral document in normalized or pixel coordinates
class DocumentQuad {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const DocumentQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// Factory for normalized quad (0.0 to 1.0)
  factory DocumentQuad.defaultNormalized({double inset = 0.08}) {
    return DocumentQuad(
      topLeft: Offset(inset, inset),
      topRight: Offset(1.0 - inset, inset),
      bottomRight: Offset(1.0 - inset, 1.0 - inset),
      bottomLeft: Offset(inset, 1.0 - inset),
    );
  }

  DocumentQuad scale(double width, double height) {
    return DocumentQuad(
      topLeft: Offset(topLeft.dx * width, topLeft.dy * height),
      topRight: Offset(topRight.dx * width, topRight.dy * height),
      bottomRight: Offset(bottomRight.dx * width, bottomRight.dy * height),
      bottomLeft: Offset(bottomLeft.dx * width, bottomLeft.dy * height),
    );
  }

  DocumentQuad toNormalized(double width, double height) {
    if (width <= 0 || height <= 0) return DocumentQuad.defaultNormalized();
    return DocumentQuad(
      topLeft: Offset(topLeft.dx / width, topLeft.dy / height),
      topRight: Offset(topRight.dx / width, topRight.dy / height),
      bottomRight: Offset(bottomRight.dx / width, bottomRight.dy / height),
      bottomLeft: Offset(bottomLeft.dx / width, bottomLeft.dy / height),
    );
  }

  List<Offset> get points => [topLeft, topRight, bottomRight, bottomLeft];

  DocumentQuad copyWith({
    Offset? topLeft,
    Offset? topRight,
    Offset? bottomRight,
    Offset? bottomLeft,
  }) {
    return DocumentQuad(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
    );
  }
}

class PerspectiveService {
  /// Computes target output size (width and height) from 4 corner points
  static Size computeOutputSize(DocumentQuad quad) {
    // Width = max of top width and bottom width
    final topW = _distance(quad.topLeft, quad.topRight);
    final botW = _distance(quad.bottomLeft, quad.bottomRight);
    final avgW = max(topW, botW);

    // Height = max of left height and right height
    final leftH = _distance(quad.topLeft, quad.bottomLeft);
    final rightH = _distance(quad.topRight, quad.bottomRight);
    final avgH = max(leftH, rightH);

    return Size(avgW.clamp(100.0, 4000.0), avgH.clamp(100.0, 4000.0));
  }

  static double _distance(Offset p1, Offset p2) {
    final dx = p1.dx - p2.dx;
    final dy = p1.dy - p2.dy;
    return sqrt(dx * dx + dy * dy);
  }

  /// Performs 4-point perspective transform warp on an img.Image
  static img.Image warpPerspective(img.Image src, DocumentQuad quad) {
    final outSize = computeOutputSize(quad);
    final outW = outSize.width.round();
    final outH = outSize.height.round();

    final dst = img.Image(width: outW, height: outH);

    final tl = quad.topLeft;
    final tr = quad.topRight;
    final br = quad.bottomRight;
    final bl = quad.bottomLeft;

    // Bilinear inverse interpolation mapping for each pixel in dst
    for (int y = 0; y < outH; y++) {
      final v = y / (outH - 1.0);
      // Interpolate along left and right edges
      final leftX = tl.dx + (bl.dx - tl.dx) * v;
      final leftY = tl.dy + (bl.dy - tl.dy) * v;

      final rightX = tr.dx + (br.dx - tr.dx) * v;
      final rightY = tr.dy + (br.dy - tr.dy) * v;

      for (int x = 0; x < outW; x++) {
        final u = x / (outW - 1.0);
        // Point in source image
        final srcX = leftX + (rightX - leftX) * u;
        final srcY = leftY + (rightY - leftY) * u;

        final px = srcX.round().clamp(0, src.width - 1);
        final py = srcY.round().clamp(0, src.height - 1);

        final pixel = src.getPixel(px, py);
        dst.setPixel(x, y, pixel);
      }
    }

    return dst;
  }

  /// Automatically detect quadrilateral document boundaries from image using radial gradient edge detection
  static DocumentQuad detectDocumentCorners(img.Image image) {
    const maxDim = 320;
    final double scale = min(maxDim / image.width, maxDim / image.height);
    final int w = (image.width * scale).round();
    final int h = (image.height * scale).round();

    final small = img.copyResize(image, width: w, height: h);
    final gray = img.grayscale(small);
    final edges = img.sobel(gray);

    final cx = w / 2.0;
    final cy = h / 2.0;

    Offset findCorner(double startX, double startY, double targetX, double targetY) {
      const steps = 70;
      double bestX = startX;
      double bestY = startY;
      double maxGrad = 0.0;
      bool foundStrong = false;

      // Scan inward along diagonal ray towards center
      for (int i = 3; i < steps; i++) {
        final t = i / steps.toDouble();
        if (t > 0.65) break; // Don't scan too close to center

        final x = (startX + (targetX - startX) * t).round().clamp(0, w - 1);
        final y = (startY + (targetY - startY) * t).round().clamp(0, h - 1);

        final lum = edges.getPixel(x, y).luminance;
        if (lum > 0.20 && lum > maxGrad) {
          maxGrad = lum.toDouble();
          bestX = x.toDouble();
          bestY = y.toDouble();
          foundStrong = true;
        }
      }

      if (!foundStrong) {
        bestX = startX + (targetX - startX) * 0.10;
        bestY = startY + (targetY - startY) * 0.10;
      }

      return Offset(
        (bestX / w).clamp(0.03, 0.97),
        (bestY / h).clamp(0.03, 0.97),
      );
    }

    final tl = findCorner(0, 0, cx, cy);
    final tr = findCorner(w.toDouble(), 0, cx, cy);
    final br = findCorner(w.toDouble(), h.toDouble(), cx, cy);
    final bl = findCorner(0, h.toDouble(), cx, cy);

    return DocumentQuad(
      topLeft: tl,
      topRight: tr,
      bottomRight: br,
      bottomLeft: bl,
    );
  }
}

