import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'storage_service.dart';

enum PdfPageFormatType {
  a4,
  letter,
  fitImage,
}

enum PdfCompressionLevel {
  low,    // Best quality, larger file
  medium, // Balanced
  high,   // Smallest file size
}

class PdfService {
  static final PdfService instance = PdfService._internal();
  PdfService._internal();

  /// Generates a PDF file from a list of image paths and optional OCR text layer
  Future<String> generatePdfFromImages({
    required List<String> imagePaths,
    required String title,
    PdfPageFormatType formatType = PdfPageFormatType.a4,
    PdfCompressionLevel compression = PdfCompressionLevel.medium,
    String? ocrText,
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'SeakScanner',
      creator: 'SeakScanner Document Suite',
    );

    PdfPageFormat pageFormat;
    switch (formatType) {
      case PdfPageFormatType.letter:
        pageFormat = PdfPageFormat.letter;
        break;
      case PdfPageFormatType.fitImage:
      case PdfPageFormatType.a4:
        pageFormat = PdfPageFormat.a4;
        break;
    }

    for (int i = 0; i < imagePaths.length; i++) {
      final imgFile = File(imagePaths[i]);
      if (!await imgFile.exists()) continue;

      final imageBytes = await imgFile.readAsBytes();
      final imageProvider = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Center(
                  child: pw.Image(
                    imageProvider,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                // Optional invisible or watermark OCR text layer for searchability
                if (ocrText != null && ocrText.isNotEmpty && i == 0)
                  pw.Positioned(
                    bottom: 10,
                    left: 10,
                    child: pw.Opacity(
                      opacity: 0.01,
                      child: pw.Text(
                        ocrText,
                        style: const pw.TextStyle(fontSize: 4),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    final outputBytes = await pdf.save();
    final outPath = await StorageService.instance.getUniquePdfPath(title);
    final outFile = File(outPath);
    await outFile.writeAsBytes(outputBytes, flush: true);
    return outPath;
  }

  /// Merges multiple PDF files into one
  Future<String> mergePdfs({
    required List<String> pdfPaths,
    required String outputTitle,
  }) async {
    final mergedPdf = pw.Document(
      title: outputTitle,
      author: 'SeakScanner',
      creator: 'SeakScanner PDF Merger',
    );

    for (final path in pdfPaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      // Rasterize existing PDF pages to re-embed in the merged document
      try {
        await for (final page in Printing.raster(bytes, dpi: 150)) {
          final pngBytes = await page.toPng();
          final image = pw.MemoryImage(pngBytes);
          mergedPdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              build: (pw.Context ctx) => pw.Center(
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error rasterizing PDF page during merge: $e');
      }
    }

    final outputBytes = await mergedPdf.save();
    final outPath = await StorageService.instance.getUniquePdfPath(outputTitle);
    final outFile = File(outPath);
    await outFile.writeAsBytes(outputBytes, flush: true);
    return outPath;
  }

  /// Splits a PDF file by extracting selected page indices (0-based)
  Future<String> splitPdf({
    required String sourcePdfPath,
    required List<int> pageIndicesToKeep,
    required String outputTitle,
  }) async {
    final splitDoc = pw.Document(
      title: outputTitle,
      author: 'SeakScanner',
    );

    final file = File(sourcePdfPath);
    final bytes = await file.readAsBytes();

    int currentIndex = 0;
    await for (final page in Printing.raster(bytes, dpi: 150)) {
      if (pageIndicesToKeep.contains(currentIndex)) {
        final pngBytes = await page.toPng();
        final image = pw.MemoryImage(pngBytes);
        splitDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
      currentIndex++;
    }

    final outputBytes = await splitDoc.save();
    final outPath = await StorageService.instance.getUniquePdfPath(outputTitle);
    await File(outPath).writeAsBytes(outputBytes, flush: true);
    return outPath;
  }

  /// Compresses a PDF file by re-rasterizing at lower DPI
  Future<String> compressPdf({
    required String sourcePdfPath,
    required PdfCompressionLevel level,
    required String outputTitle,
  }) async {
    double dpi = 150.0;
    switch (level) {
      case PdfCompressionLevel.low:
        dpi = 130.0;
        break;
      case PdfCompressionLevel.medium:
        dpi = 96.0;
        break;
      case PdfCompressionLevel.high:
        dpi = 72.0;
        break;
    }

    final compressedDoc = pw.Document(title: outputTitle);
    final bytes = await File(sourcePdfPath).readAsBytes();

    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      final pngBytes = await page.toPng();
      final image = pw.MemoryImage(pngBytes);
      compressedDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final outputBytes = await compressedDoc.save();
    final outPath = await StorageService.instance.getUniquePdfPath(outputTitle);
    await File(outPath).writeAsBytes(outputBytes, flush: true);
    return outPath;
  }

  /// Prints document via system print dialog
  Future<void> printPdf(String pdfPath, {required String title}) async {
    final file = File(pdfPath);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: title,
    );
  }

  /// Shares PDF file via native system share sheet
  Future<void> shareFile(String filePath, {String? text}) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    await Share.shareXFiles(
      [XFile(filePath)],
      text: text ?? 'Shared from SeakScanner',
    );
  }

  /// Shares multiple files (e.g. JPG pages)
  Future<void> shareMultipleFiles(List<String> filePaths, {String? text}) async {
    final xfiles = filePaths.map((p) => XFile(p)).toList();
    await Share.shareXFiles(xfiles, text: text ?? 'Shared from SeakScanner');
  }
}
