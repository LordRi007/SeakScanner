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
  /// using blurred multi-profile density analysis and edge-guided corner refinement.
  static DocumentQuad detectDocumentCorners(img.Image image) {
    const targetW = 240;
    final double scale = targetW / image.width;
    final int w = targetW;
    final int h = (image.height * scale).round().clamp(60, 600);

    final small = img.copyResize(image, width: w, height: h);
    final gray = img.grayscale(small);
    // Gaussian blur suppresses interior text and fine textures while keeping main borders
    final blurred = img.gaussianBlur(gray, radius: 2);
    final edges = img.sobel(blurred);

    // Zero out outer 3 boundary pixels to remove Sobel convolution artifacts
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (x < 3 || x >= w - 3 || y < 3 || y >= h - 3) {
          edges.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }

    // Measure perimeter background noise (rows 4..14)
    double bgEdgeSum = 0;
    int bgEdgeCount = 0;
    for (int y = 4; y <= 14; y++) {
      for (int x = 4; x < w - 4; x++) {
        bgEdgeSum += edges.getPixel(x, y).luminance;
        bgEdgeCount++;
      }
    }
    final double bgMean = bgEdgeCount > 0 ? (bgEdgeSum / bgEdgeCount) : 25.0;
    final double edgeThresh = max(32.0, bgMean * 1.35);

    // Compute row and column edge densities
    final rowScores = List<double>.filled(h, 0.0);
    for (int y = 3; y < h - 3; y++) {
      int count = 0;
      for (int x = 3; x < w - 3; x++) {
        if (edges.getPixel(x, y).luminance > edgeThresh) count++;
      }
      rowScores[y] = count / (w - 6);
    }

    final colScores = List<double>.filled(w, 0.0);
    for (int x = 3; x < w - 3; x++) {
      int count = 0;
      for (int y = 3; y < h - 3; y++) {
        if (edges.getPixel(x, y).luminance > edgeThresh) count++;
      }
      colScores[x] = count / (h - 6);
    }

    // 5% edge density marks start of document boundary
    const densityThresh = 0.05;

    int yTop = 4;
    while (yTop < h * 0.45 && rowScores[yTop] < densityThresh) {
      yTop++;
    }

    int yBot = h - 4;
    while (yBot > h * 0.55 && rowScores[yBot] < densityThresh) {
      yBot--;
    }

    int xLeft = 4;
    while (xLeft < w * 0.45 && colScores[xLeft] < densityThresh) {
      xLeft++;
    }

    int xRight = w - 4;
    while (xRight > w * 0.55 && colScores[xRight] < densityThresh) {
      xRight--;
    }

    // Local edge search helpers
    double findEdgeY(int colX, int startY, int endY, int step) {
      for (int y = startY; (step > 0 ? y <= endY : y >= endY); y += step) {
        if (edges.getPixel(colX, y).luminance > edgeThresh) {
          return y.toDouble();
        }
      }
      return startY.toDouble();
    }

    double findEdgeX(int rowY, int startX, int endX, int step) {
      for (int x = startX; (step > 0 ? x <= endX : x >= endX); x += step) {
        if (edges.getPixel(x, rowY).luminance > edgeThresh) {
          return x.toDouble();
        }
      }
      return startX.toDouble();
    }

    // Refine corners along the 4 borders
    final tlX = findEdgeX(yTop + 4, max(3, xLeft - 8), min(w - 3, xLeft + 20), 1) / w;
    final tlY = findEdgeY(xLeft + 4, max(3, yTop - 8), min(h - 3, yTop + 20), 1) / h;

    final trX = findEdgeX(yTop + 4, min(w - 4, xRight + 8), max(3, xRight - 20), -1) / w;
    final trY = findEdgeY(xRight - 4, max(3, yTop - 8), min(h - 3, yTop + 20), 1) / h;

    final brX = findEdgeX(yBot - 4, min(w - 4, xRight + 8), max(3, xRight - 20), -1) / w;
    final brY = findEdgeY(xRight - 4, min(h - 4, yBot + 8), max(3, yBot - 20), -1) / h;

    final blX = findEdgeX(yBot - 4, max(3, xLeft - 8), min(w - 3, xLeft + 20), 1) / w;
    final blY = findEdgeY(xLeft + 4, min(h - 4, yBot + 8), max(3, yBot - 20), -1) / h;

    final tl = Offset(tlX.clamp(0.03, 0.40), tlY.clamp(0.02, 0.40));
    final tr = Offset(trX.clamp(0.60, 0.97), trY.clamp(0.02, 0.40));
    final br = Offset(brX.clamp(0.60, 0.97), brY.clamp(0.60, 0.98));
    final bl = Offset(blX.clamp(0.03, 0.40), blY.clamp(0.60, 0.98));

    // Calculate quadrilateral area using Shoelace formula
    final area = 0.5 * (
      (tl.dx * tr.dy - tr.dx * tl.dy) +
      (tr.dx * br.dy - br.dx * tr.dy) +
      (br.dx * bl.dy - bl.dx * br.dy) +
      (bl.dx * tl.dy - tl.dx * bl.dy)
    ).abs();

    // Sanity check: must be convex, valid boundaries, and cover reasonable area (>25%)
    if (area < 0.25 || tr.dx <= tl.dx + 0.1 || br.dx <= bl.dx + 0.1 || bl.dy <= tl.dy + 0.1 || br.dy <= tr.dy + 0.1) {
      // Default clean document frame with 6% margins
      return const DocumentQuad(
        topLeft: Offset(0.06, 0.06),
        topRight: Offset(0.94, 0.06),
        bottomRight: Offset(0.94, 0.94),
        bottomLeft: Offset(0.06, 0.94),
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

