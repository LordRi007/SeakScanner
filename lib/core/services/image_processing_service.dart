import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum EnhancementFilter {
  original,
  auto,
  magic,
  bw,
  grayscale,
  highContrast,
  sharpen,
}

class ImageProcessingService {
  static final ImageProcessingService instance = ImageProcessingService._internal();
  ImageProcessingService._internal();

  /// Loads image bytes and decodes into img.Image
  static img.Image? decodeImage(Uint8List bytes) {
    return img.decodeImage(bytes);
  }

  /// Encodes img.Image to JPG bytes
  static Uint8List encodeJpg(img.Image image, {int quality = 85}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Enhances an image file asynchronously using compute / Isolate
  Future<Uint8List> processImageFile({
    required String filePath,
    required EnhancementFilter filter,
    double brightness = 0.0, // -100 to 100
    double contrast = 0.0,   // -100 to 100
    int rotationAngle = 0,   // 0, 90, 180, 270
    int quality = 85,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    return compute(
      _processImageWorker,
      _ProcessParams(
        bytes: bytes,
        filter: filter,
        brightness: brightness,
        contrast: contrast,
        rotationAngle: rotationAngle,
        quality: quality,
      ),
    );
  }

  /// Processes raw Uint8List bytes in isolate
  Future<Uint8List> processImageBytes({
    required Uint8List bytes,
    required EnhancementFilter filter,
    double brightness = 0.0,
    double contrast = 0.0,
    int rotationAngle = 0,
    int quality = 85,
  }) async {
    return compute(
      _processImageWorker,
      _ProcessParams(
        bytes: bytes,
        filter: filter,
        brightness: brightness,
        contrast: contrast,
        rotationAngle: rotationAngle,
        quality: quality,
      ),
    );
  }

  /// Creates a compressed thumbnail in isolate
  Future<Uint8List> createThumbnail(Uint8List bytes, {int maxDimension = 320}) async {
    return compute(_thumbnailWorker, _ThumbnailParams(bytes: bytes, maxDimension: maxDimension));
  }
}

class _ProcessParams {
  final Uint8List bytes;
  final EnhancementFilter filter;
  final double brightness;
  final double contrast;
  final int rotationAngle;
  final int quality;

  _ProcessParams({
    required this.bytes,
    required this.filter,
    required this.brightness,
    required this.contrast,
    required this.rotationAngle,
    required this.quality,
  });
}

class _ThumbnailParams {
  final Uint8List bytes;
  final int maxDimension;
  _ThumbnailParams({required this.bytes, required this.maxDimension});
}

Uint8List _thumbnailWorker(_ThumbnailParams params) {
  final image = img.decodeImage(params.bytes);
  if (image == null) return params.bytes;

  img.Image thumb;
  if (image.width > image.height) {
    thumb = img.copyResize(image, width: params.maxDimension);
  } else {
    thumb = img.copyResize(image, height: params.maxDimension);
  }
  return Uint8List.fromList(img.encodeJpg(thumb, quality: 75));
}

Uint8List _processImageWorker(_ProcessParams params) {
  img.Image? image = img.decodeImage(params.bytes);
  if (image == null) return params.bytes;

  // 1. Rotation
  if (params.rotationAngle != 0) {
    image = img.copyRotate(image, angle: params.rotationAngle);
  }

  // 2. Filter application
  switch (params.filter) {
    case EnhancementFilter.original:
      // No filter modification
      break;

    case EnhancementFilter.auto:
      // Auto levels: stretch contrast and normalize
      image = img.normalize(image, min: 20, max: 245);
      image = img.adjustColor(image, contrast: 1.15, saturation: 1.05);
      break;

    case EnhancementFilter.magic:
      // CamScanner Magic Color algorithm:
      // Whitens document background while making black text sharp and dark,
      // and preserving color stamps / headers.
      image = _applyMagicColor(image);
      break;

    case EnhancementFilter.bw:
      // B&W Adaptive threshold / binarization
      image = _applyAdaptiveBinary(image);
      break;

    case EnhancementFilter.grayscale:
      image = img.grayscale(image);
      image = img.normalize(image, min: 10, max: 245);
      break;

    case EnhancementFilter.highContrast:
      image = img.grayscale(image);
      image = img.contrast(image, contrast: 150);
      break;

    case EnhancementFilter.sharpen:
      // Sharpen convolution kernel
      image = _applySharpen(image);
      break;
  }

  // 3. User Brightness Adjustment (-100..100 -> factor ~ 0.5..1.5)
  if (params.brightness != 0.0) {
    final factor = 1.0 + (params.brightness / 100.0) * 0.5;
    image = img.adjustColor(image, brightness: factor);
  }

  // 4. User Contrast Adjustment (-100..100 -> factor ~ 0.5..1.5)
  if (params.contrast != 0.0) {
    final factor = 1.0 + (params.contrast / 100.0) * 0.5;
    image = img.adjustColor(image, contrast: factor);
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
}

/// Magic Color enhancement filter
img.Image _applyMagicColor(img.Image src) {
  final out = img.Image.from(src);

  // 1. Whitening threshold and ink enhancement
  for (int y = 0; y < out.height; y++) {
    for (int x = 0; x < out.width; x++) {
      final p = out.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;

      // Calculate luminance
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;

      // If background-like (bright grey/yellowish paper), push to near pure white
      if (lum > 170) {
        final push = ((lum - 170) / 85.0).clamp(0.0, 1.0);
        final newR = (r + (255 - r) * push * 0.9).round().clamp(0, 255);
        final newG = (g + (255 - g) * push * 0.9).round().clamp(0, 255);
        final newB = (b + (255 - b) * push * 0.9).round().clamp(0, 255);
        out.setPixelRgb(x, y, newR, newG, newB);
      } else if (lum < 110) {
        // Dark ink text: deepen and enrich
        final newR = (r * 0.85).round().clamp(0, 255);
        final newG = (g * 0.85).round().clamp(0, 255);
        final newB = (b * 0.85).round().clamp(0, 255);
        out.setPixelRgb(x, y, newR, newG, newB);
      }
    }
  }

  // Boost sharpness & saturation slightly for crisp letters
  return _applySharpen(img.adjustColor(out, saturation: 1.12, contrast: 1.15));
}

/// Adaptive thresholding for clean black-and-white documents
img.Image _applyAdaptiveBinary(img.Image src) {
  final gray = img.grayscale(src);
  final out = img.Image(width: gray.width, height: gray.height);

  // Calculate average luminance
  double totalLum = 0;
  const sampleStep = 4;
  int count = 0;
  for (int y = 0; y < gray.height; y += sampleStep) {
    for (int x = 0; x < gray.width; x += sampleStep) {
      totalLum += gray.getPixel(x, y).r;
      count++;
    }
  }
  final threshold = count > 0 ? (totalLum / count) * 0.88 : 128.0;

  for (int y = 0; y < gray.height; y++) {
    for (int x = 0; x < gray.width; x++) {
      final p = gray.getPixel(x, y);
      if (p.r >= threshold) {
        out.setPixelRgb(x, y, 255, 255, 255); // White paper
      } else {
        out.setPixelRgb(x, y, 20, 20, 25);     // Crisp dark ink
      }
    }
  }

  return out;
}

/// 3x3 Sharpen filter
img.Image _applySharpen(img.Image src) {
  return img.convolution(
    src,
    filter: [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0,
    ],
    div: 1,
    offset: 0,
  );
}
