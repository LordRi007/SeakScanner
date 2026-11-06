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

  /// Automatically detect quadrilateral document boundaries from image
  /// using outside-in border edge scanning with geometry validation.
  static DocumentQuad detectDocumentCorners(img.Image image) {
    const maxDim = 320;
    final double scale = min(maxDim / image.width, maxDim / image.height);
    final int w = (image.width * scale).round().clamp(50, 800);
    final int h = (image.height * scale).round().clamp(50, 800);

    final small = img.copyResize(image, width: w, height: h);
    final gray = img.grayscale(small);
    final edges = img.sobel(gray);

    // Compute border noise baseline from outer perimeter
    double borderSum = 0;
    int borderCount = 0;
    for (int x = 0; x < w; x++) {
      borderSum += edges.getPixel(x, 1).luminance;
      borderSum += edges.getPixel(x, h - 2).luminance;
      borderCount += 2;
    }
    for (int y = 0; y < h; y++) {
      borderSum += edges.getPixel(1, y).luminance;
      borderSum += edges.getPixel(w - 2, y).luminance;
      borderCount += 2;
    }
    final double borderMean = borderCount > 0 ? (borderSum / borderCount) : 0.05;
    final double edgeThreshold = max(0.18, borderMean * 1.8);

    // Scan from top down to find top document edge
    double findTopEdge(double xNorm) {
      final x = (xNorm * w).round().clamp(0, w - 1);
      final maxScanY = (h * 0.45).round();
      for (int y = 3; y < maxScanY; y++) {
        if (edges.getPixel(x, y).luminance > edgeThreshold) {
          return y / h;
        }
      }
      return 0.04;
    }

    // Scan from bottom up to find bottom document edge
    double findBottomEdge(double xNorm) {
      final x = (xNorm * w).round().clamp(0, w - 1);
      final minScanY = (h * 0.55).round();
      for (int y = h - 4; y > minScanY; y--) {
        if (edges.getPixel(x, y).luminance > edgeThreshold) {
          return y / h;
        }
      }
      return 0.96;
    }

    // Scan from left inward to find left document edge
    double findLeftEdge(double yNorm) {
      final y = (yNorm * h).round().clamp(0, h - 1);
      final maxScanX = (w * 0.45).round();
      for (int x = 3; x < maxScanX; x++) {
        if (edges.getPixel(x, y).luminance > edgeThreshold) {
          return x / w;
        }
      }
      return 0.04;
    }

    // Scan from right inward to find right document edge
    double findRightEdge(double yNorm) {
      final y = (yNorm * h).round().clamp(0, h - 1);
      final minScanX = (w * 0.55).round();
      for (int x = w - 4; x > minScanX; x--) {
        if (edges.getPixel(x, y).luminance > edgeThreshold) {
          return x / w;
        }
      }
      return 0.96;
    }

    // Multi-point sampling for perspective corners
    final topAtLeft = findTopEdge(0.20);
    final topAtRight = findTopEdge(0.80);
    final botAtLeft = findBottomEdge(0.20);
    final botAtRight = findBottomEdge(0.80);

    final leftAtTop = findLeftEdge(0.20);
    final leftAtBot = findLeftEdge(0.80);
    final rightAtTop = findRightEdge(0.20);
    final rightAtBot = findRightEdge(0.80);

    final tl = Offset(leftAtTop.clamp(0.02, 0.40), topAtLeft.clamp(0.02, 0.40));
    final tr = Offset(rightAtTop.clamp(0.60, 0.98), topAtRight.clamp(0.02, 0.40));
    final br = Offset(rightAtBot.clamp(0.60, 0.98), botAtRight.clamp(0.60, 0.98));
    final bl = Offset(leftAtBot.clamp(0.02, 0.40), botAtLeft.clamp(0.60, 0.98));

    // Calculate quadrilateral area using Shoelace formula
    final area = 0.5 * (
      (tl.dx * tr.dy - tr.dx * tl.dy) +
      (tr.dx * br.dy - br.dx * tr.dy) +
      (br.dx * bl.dy - bl.dx * br.dy) +
      (bl.dx * tl.dy - tl.dx * bl.dy)
    ).abs();

    // Sanity check: must be convex, valid boundaries, and cover reasonable area (>35%)
    if (area < 0.35 || tr.dx <= tl.dx || br.dx <= bl.dx || bl.dy <= tl.dy || br.dy <= tr.dy) {
      // Default clean document frame with 4% margins
      return const DocumentQuad(
        topLeft: Offset(0.04, 0.04),
        topRight: Offset(0.96, 0.04),
        bottomRight: Offset(0.96, 0.96),
        bottomLeft: Offset(0.04, 0.96),
      );
    }

    return DocumentQuad(
      topLeft: tl,
      topRight: tr,
      bottomRight: br,
      bottomLeft: bl,
    );
  }
}

