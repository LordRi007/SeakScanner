import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/theme.dart';
import '../database/models/document_model.dart';
import '../database/models/page_model.dart';
import '../localization/app_localizations.dart';
import 'storage_service.dart';

enum ExportFormat {
  pdf,
  excel,
  docx,
  csv,
}

class ExportDownloadService {
  static final ExportDownloadService instance = ExportDownloadService._internal();
  ExportDownloadService._internal();

  // -------------------------------------------------------------
  // 1. IMAGE DOWNLOADS
  // -------------------------------------------------------------

  /// Downloads a single page image to the device Downloads folder
  Future<String> downloadPageImage({
    required String imagePath,
    required String documentTitle,
    int? pageIndex,
  }) async {
    final cleanTitle = documentTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final pageSuffix = pageIndex != null ? '_page_${pageIndex + 1}' : '';
    final ext = p.extension(imagePath).isNotEmpty ? p.extension(imagePath) : '.jpg';
    final targetName = 'Seak_$cleanTitle$pageSuffix$ext';

    return await StorageService.instance.copyFileToDownloads(
      imagePath,
      targetFileName: targetName,
    );
  }

  /// Downloads all pages of a document as individual image files
  Future<List<String>> downloadAllPageImages({
    required List<PageModel> pages,
    required String documentTitle,
  }) async {
    final cleanTitle = documentTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final downloadedPaths = <String>[];

    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      final ext = p.extension(page.enhancedImagePath).isNotEmpty
          ? p.extension(page.enhancedImagePath)
          : '.jpg';
      final fileName = 'Seak_${cleanTitle}_page_${i + 1}$ext';

      final saved = await StorageService.instance.copyFileToDownloads(
        page.enhancedImagePath,
        targetFileName: fileName,
      );
      downloadedPaths.add(saved);
    }

    return downloadedPaths;
  }

  // -------------------------------------------------------------
  // 2. DOCUMENT LIST EXPORT (PDF, Excel, Word DOCX, CSV)
  // -------------------------------------------------------------

  /// Exports a list of documents to a beautifully formatted PDF report
  Future<String> exportDocumentListToPdf(
    List<DocumentModel> docs, {
    String title = 'Document List Report',
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'SeakScanner',
      creator: 'SeakScanner Document Suite',
    );

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final totalPages = docs.fold<int>(0, (sum, d) => sum + d.pageCount);
    final totalSizeBytes = docs.fold<int>(0, (sum, d) => sum + d.fileSizeBytes);
    final totalSizeStr = _formatBytes(totalSizeBytes);

    pw.Font? baseFont;
    try {
      baseFont = await PdfGoogleFonts.robotoRegular();
    } catch (_) {
      baseFont = pw.Font.helvetica();
    }

    pw.Font? boldFont;
    try {
      boldFont = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      boldFont = pw.Font.helveticaBold();
    }

    final tableData = <List<String>>[];
    for (int i = 0; i < docs.length; i++) {
      final d = docs[i];
      tableData.add([
        '${i + 1}',
        d.title,
        DateFormat('yyyy-MM-dd HH:mm').format(d.createdAt),
        '${d.pageCount}',
        d.formattedSize,
        d.isFavorite ? 'Starred' : '-',
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            margin: const pw.EdgeInsets.only(bottom: 14),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue700, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SeakScanner',
                      style: pw.TextStyle(
                        color: PdfColors.blue800,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Smart Document Inventory & Catalog',
                      style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: $dateStr',
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
                    ),
                    pw.Text(
                      'Total: ${docs.length} docs | $totalPages pgs | $totalSizeStr',
                      style: pw.TextStyle(
                        color: PdfColors.blue800,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount} | SeakScanner Document Suite',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
            ),
          );
        },
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Document Name', 'Created Date', 'Pages', 'Size', 'Status'],
            data: tableData,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              0: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'SeakScanner_Document_List_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    return await StorageService.instance.saveFileToDownloads(bytes, fileName);
  }

  /// Exports a list of documents to a native Microsoft Excel (.xlsx) workbook
  Future<String> exportDocumentListToExcel(
    List<DocumentModel> docs, {
    String title = 'Document_List',
  }) async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Documents';
    final sheet = excel[sheetName];

    // Add Table Header Row
    sheet.appendRow([
      TextCellValue('No.'),
      TextCellValue('Document Title'),
      TextCellValue('Created Date'),
      TextCellValue('Last Updated'),
      TextCellValue('Pages'),
      TextCellValue('File Size'),
      TextCellValue('Starred'),
      TextCellValue('OCR Extracted Content Preview'),
    ]);

    // Format Header Row
    for (int col = 0; col < 8; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
        horizontalAlign: HorizontalAlign.Center,
      );
    }

    // Populate Data Rows
    for (int i = 0; i < docs.length; i++) {
      final d = docs[i];
      final ocr = d.ocrFullText ?? '';
      final previewText = ocr.isNotEmpty
          ? ocr.replaceAll('\n', ' ').trim()
          : '';

      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(d.title),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(d.createdAt)),
        TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(d.updatedAt)),
        IntCellValue(d.pageCount),
        TextCellValue(d.formattedSize),
        TextCellValue(d.isFavorite ? 'Starred' : '-'),
        TextCellValue(previewText.length > 200 ? '${previewText.substring(0, 200)}...' : previewText),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }

    final now = DateTime.now();
    final fileName = 'SeakScanner_Document_List_${DateFormat('yyyyMMdd_HHmmss').format(now)}.xlsx';
    return await StorageService.instance.saveFileToDownloads(bytes, fileName);
  }

  /// Exports a list of documents to a native Microsoft Word (.docx) document
  Future<String> exportDocumentListToDocx(
    List<DocumentModel> docs, {
    String title = 'Document List Report',
  }) async {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final totalPages = docs.fold<int>(0, (sum, d) => sum + d.pageCount);
    final totalSizeStr = _formatBytes(docs.fold<int>(0, (sum, d) => sum + d.fileSizeBytes));

    final tableRows = <List<String>>[];
    tableRows.add(['#', 'Document Title', 'Created Date', 'Pages', 'Size', 'Starred']);

    for (int i = 0; i < docs.length; i++) {
      final d = docs[i];
      tableRows.add([
        '${i + 1}',
        d.title,
        DateFormat('yyyy-MM-dd HH:mm').format(d.createdAt),
        '${d.pageCount}',
        d.formattedSize,
        d.isFavorite ? 'Starred' : '-',
      ]);
    }

    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.write('<w:body>');

    // Title
    buffer.write(_docxParagraph('SeakScanner - Document Inventory Report', isHeading: true, isBold: true, size: 36, color: '1E3A8A'));
    // Subtitle & Summary
    buffer.write(_docxParagraph('Generated on $dateStr | SeakScanner Smart Document Manager', isBold: false, size: 20, color: '6B7280'));
    buffer.write(_docxParagraph('Total Documents: ${docs.length}  |  Total Pages: $totalPages  |  Total Size: $totalSizeStr', isBold: true, size: 22, color: '2563EB'));
    buffer.write(_docxParagraph('', size: 14)); // spacing

    // Table
    buffer.write(_docxTable(tableRows));

    // Section properties (A4)
    buffer.write('<w:sectPr>');
    buffer.write('<w:pgSz w:w="11906" w:h="16838"/>');
    buffer.write('<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>');
    buffer.write('</w:sectPr>');
    buffer.write('</w:body></w:document>');

    final docxBytes = _buildDocxZip(buffer.toString());
    final fileName = 'SeakScanner_Document_List_${DateFormat('yyyyMMdd_HHmmss').format(now)}.docx';
    return await StorageService.instance.saveFileToDownloads(docxBytes, fileName);
  }

  /// Exports a list of documents to a standard CSV file
  Future<String> exportDocumentListToCsv(
    List<DocumentModel> docs, {
    String title = 'Document_List',
  }) async {
    final buffer = StringBuffer();
    // UTF-8 BOM for universal Excel recognition
    buffer.write('\uFEFF');

    // Headers
    buffer.writeln('"No.","Document Title","Created Date","Last Updated","Pages","File Size","Starred","Content Preview"');

    for (int i = 0; i < docs.length; i++) {
      final d = docs[i];
      final ocr = d.ocrFullText ?? '';
      final preview = ocr.isNotEmpty
          ? ocr.replaceAll('\n', ' ').replaceAll('"', '""').trim()
          : '';
      final titleEscaped = d.title.replaceAll('"', '""');

      buffer.writeln(
        '"${i + 1}","$titleEscaped","${DateFormat('yyyy-MM-dd HH:mm').format(d.createdAt)}","${DateFormat('yyyy-MM-dd HH:mm').format(d.updatedAt)}","${d.pageCount}","${d.formattedSize}","${d.isFavorite ? 'Yes' : 'No'}","$preview"',
      );
    }

    final bytes = utf8.encode(buffer.toString());
    final now = DateTime.now();
    final fileName = 'SeakScanner_Document_List_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
    return await StorageService.instance.saveFileToDownloads(bytes, fileName);
  }

  // -------------------------------------------------------------
  // 3. DOCUMENT CONTENT / TEXT EXPORT (PDF, Word, Excel, TXT)
  // -------------------------------------------------------------

  /// Exports raw or OCR text content to any requested format
  Future<String> exportTextContent({
    required String text,
    required String title,
    required ExportFormat format,
  }) async {
    final cleanTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);

    switch (format) {
      case ExportFormat.pdf:
        final pdf = pw.Document(title: title);
        pw.Font? baseFont;
        try {
          baseFont = await PdfGoogleFonts.robotoRegular();
        } catch (_) {
          baseFont = pw.Font.helvetica();
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: baseFont),
            header: (ctx) => pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue700, width: 1.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(now), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            footer: (ctx) => pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 12),
              child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ),
            build: (ctx) => [
              pw.Paragraph(
                text: text,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
              ),
            ],
          ),
        );
        final bytes = await pdf.save();
        return await StorageService.instance.saveFileToDownloads(bytes, 'Seak_${cleanTitle}_$dateStr.pdf');

      case ExportFormat.docx:
        final buffer = StringBuffer();
        buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
        buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
        buffer.write('<w:body>');
        buffer.write(_docxParagraph(title, isHeading: true, isBold: true, size: 32, color: '1E3A8A'));
        buffer.write(_docxParagraph('Exported on ${DateFormat('yyyy-MM-dd HH:mm').format(now)}', isBold: false, size: 18, color: '6B7280'));
        buffer.write(_docxParagraph('', size: 16));

        final lines = text.split('\n');
        for (final line in lines) {
          buffer.write(_docxParagraph(line.isNotEmpty ? line : ' ', size: 22, color: '1F2937'));
        }

        buffer.write('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/></w:sectPr>');
        buffer.write('</w:body></w:document>');

        final docxBytes = _buildDocxZip(buffer.toString());
        return await StorageService.instance.saveFileToDownloads(docxBytes, 'Seak_${cleanTitle}_$dateStr.docx');

      case ExportFormat.excel:
        final excel = Excel.createExcel();
        final sheet = excel[excel.getDefaultSheet() ?? 'Text_Data'];
        sheet.appendRow([TextCellValue('Line #'), TextCellValue('Extracted Content')]);

        final headerCell1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
        final headerCell2 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
        final style = CellStyle(
          bold: true,
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
        );
        headerCell1.cellStyle = style;
        headerCell2.cellStyle = style;

        final lines = text.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].trim().isNotEmpty) {
            sheet.appendRow([IntCellValue(i + 1), TextCellValue(lines[i])]);
          }
        }

        final bytes = excel.save()!;
        return await StorageService.instance.saveFileToDownloads(bytes, 'Seak_${cleanTitle}_$dateStr.xlsx');

      case ExportFormat.csv:
        final buffer = StringBuffer();
        buffer.write('\uFEFF');
        final lines = text.split('\n');
        for (final line in lines) {
          buffer.writeln('"${line.replaceAll('"', '""')}"');
        }
        final bytes = utf8.encode(buffer.toString());
        return await StorageService.instance.saveFileToDownloads(bytes, 'Seak_${cleanTitle}_$dateStr.csv');
    }
  }

  // -------------------------------------------------------------
  // 4. USER INTERACTION BOTTOM SHEETS & SNACKBARS
  // -------------------------------------------------------------

  /// Presents a bottom sheet to download the documents list to a file
  Future<void> showExportListBottomSheet(
    BuildContext context, {
    required List<DocumentModel> docs,
    String? customTitle,
  }) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No documents available to export.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.file_download_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('downloadList'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            '${docs.length} ${l10n.t('pages').toLowerCase() == 'pages' ? 'documents selected' : 'ឯកសារ'}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildFormatTile(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: l10n.t('exportAsPdf'),
                  subtitle: 'Formatted PDF catalog & summary report',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportDocumentListToPdf(docs, title: customTitle ?? 'Documents List'));
                  },
                ),
                _buildFormatTile(
                  icon: Icons.table_chart_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: l10n.t('exportAsExcel'),
                  subtitle: 'Full Microsoft Excel workbook (.xlsx)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportDocumentListToExcel(docs, title: customTitle ?? 'Documents_List'));
                  },
                ),
                _buildFormatTile(
                  icon: Icons.article_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: l10n.t('exportAsDocx'),
                  subtitle: 'Microsoft Word document with structured table (.docx)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportDocumentListToDocx(docs, title: customTitle ?? 'Documents List'));
                  },
                ),
                _buildFormatTile(
                  icon: Icons.text_snippet_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: l10n.t('exportAsCsv'),
                  subtitle: 'Universal comma-separated spreadsheet data',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportDocumentListToCsv(docs, title: customTitle ?? 'Documents_List'));
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Presents a bottom sheet to download single or all document images
  Future<void> showDownloadImageBottomSheet(
    BuildContext context, {
    required List<PageModel> pages,
    required int activeIndex,
    required String documentTitle,
  }) async {
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No page images to download.')),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);

    // If single page, download directly
    if (pages.length == 1) {
      await _executeDownloadImage(
        context,
        imagePath: pages[0].enhancedImagePath,
        documentTitle: documentTitle,
        pageIndex: 0,
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.image_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('downloadImage'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            documentTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildFormatTile(
                  icon: Icons.photo_rounded,
                  iconColor: AppColors.primary,
                  title: '${l10n.t('downloadCurrentImage')} (${activeIndex + 1}/${pages.length})',
                  subtitle: 'Save this page image directly to Downloads folder',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeDownloadImage(
                      context,
                      imagePath: pages[activeIndex].enhancedImagePath,
                      documentTitle: documentTitle,
                      pageIndex: activeIndex,
                    );
                  },
                ),
                _buildFormatTile(
                  icon: Icons.photo_library_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: '${l10n.t('downloadAllImages')} (${pages.length} images)',
                  subtitle: 'Save all scanned pages as images into Downloads',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeDownloadAllImages(
                      context,
                      pages: pages,
                      documentTitle: documentTitle,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Presents a bottom sheet to download OCR/extracted text to PDF, Word, Excel, or TXT
  Future<void> showExportTextBottomSheet(
    BuildContext context, {
    required String text,
    required String title,
  }) async {
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.file_download_rounded, color: AppColors.secondary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('exportFormatTitle'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildFormatTile(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: l10n.t('exportAsPdf'),
                  subtitle: 'Save text as formatted printable PDF',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportTextContent(text: text, title: title, format: ExportFormat.pdf));
                  },
                ),
                _buildFormatTile(
                  icon: Icons.article_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: l10n.t('exportAsDocx'),
                  subtitle: 'Save text as editable Microsoft Word document (.docx)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportTextContent(text: text, title: title, format: ExportFormat.docx));
                  },
                ),
                _buildFormatTile(
                  icon: Icons.table_chart_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: l10n.t('exportAsExcel'),
                  subtitle: 'Save text lines & tables to Excel (.xlsx)',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportTextContent(text: text, title: title, format: ExportFormat.excel));
                  },
                ),
                _buildFormatTile(
                  icon: Icons.description_rounded,
                  iconColor: const Color(0xFF64748B),
                  title: 'Text Document (.txt)',
                  subtitle: 'Plain text file compatible with all editors',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _executeExport(context, () => exportTextContent(text: text, title: title, format: ExportFormat.csv));
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // INTERNAL HELPERS
  // -------------------------------------------------------------

  Widget _buildFormatTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      onTap: onTap,
    );
  }

  Future<void> _executeExport(BuildContext context, Future<String> Function() action) async {
    final l10n = AppLocalizations.of(context);
    try {
      final savedPath = await action();
      if (!context.mounted) return;
      showSuccessFeedback(context, savedPath, l10n.t('fileSavedSuccess'));
    } catch (e) {
      debugPrint('Export error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _executeDownloadImage(
    BuildContext context, {
    required String imagePath,
    required String documentTitle,
    int? pageIndex,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      final savedPath = await downloadPageImage(
        imagePath: imagePath,
        documentTitle: documentTitle,
        pageIndex: pageIndex,
      );
      if (!context.mounted) return;
      showSuccessFeedback(context, savedPath, l10n.t('imageSavedSuccess'));
    } catch (e) {
      debugPrint('Image download error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _executeDownloadAllImages(
    BuildContext context, {
    required List<PageModel> pages,
    required String documentTitle,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      final savedPaths = await downloadAllPageImages(pages: pages, documentTitle: documentTitle);
      if (!context.mounted) return;
      if (savedPaths.isNotEmpty) {
        showSuccessFeedback(
          context,
          savedPaths.first,
          '${pages.length} ${l10n.t('imageSavedSuccess')}',
        );
      }
    } catch (e) {
      debugPrint('All images download error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void showSuccessFeedback(BuildContext context, String filePath, String title) {
    final fileName = p.basename(filePath);
    final l10n = AppLocalizations.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(fileName, style: const TextStyle(fontSize: 11, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.t('open').toUpperCase(),
          textColor: Colors.white,
          onPressed: () {
            OpenFilex.open(filePath);
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // DOCX XML GENERATOR HELPERS
  // -------------------------------------------------------------

  List<int> _buildDocxZip(String documentXml) {
    final archive = Archive();

    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    const docRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>''';

    void addXml(String name, String xml) {
      final bytes = utf8.encode(xml);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addXml('[Content_Types].xml', contentTypesXml);
    addXml('_rels/.rels', relsXml);
    addXml('word/_rels/document.xml.rels', docRelsXml);
    addXml('word/styles.xml', stylesXml);
    addXml('word/document.xml', documentXml);

    final encoded = ZipEncoder().encode(archive);
    return encoded ?? [];
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _docxParagraph(
    String text, {
    bool isHeading = false,
    bool isBold = false,
    int size = 22,
    String color = '333333',
  }) {
    final escaped = _escapeXml(text);
    final boldXml = isBold ? '<w:b/><w:bCs/>' : '';
    final headingXml = isHeading ? '<w:pStyle w:val="Heading1"/>' : '';
    return '<w:p><w:pPr>$headingXml</w:pPr><w:r><w:rPr>$boldXml<w:color w:val="$color"/><w:sz w:val="$size"/><w:szCs w:val="$size"/></w:rPr><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  String _docxTable(List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.write('<w:tbl>');
    buffer.write('<w:tblPr>');
    buffer.write('<w:tblW w:w="0" w:type="auto"/>');
    buffer.write('<w:tblBorders>');
    buffer.write('<w:top w:val="single" w:sz="6" w:space="0" w:color="D1D5DB"/>');
    buffer.write('<w:left w:val="none"/>');
    buffer.write('<w:bottom w:val="single" w:sz="12" w:space="0" w:color="9CA3AF"/>');
    buffer.write('<w:right w:val="none"/>');
    buffer.write('<w:insideH w:val="single" w:sz="4" w:space="0" w:color="E5E7EB"/>');
    buffer.write('<w:insideV w:val="none"/>');
    buffer.write('</w:tblBorders>');
    buffer.write('</w:tblPr>');

    for (int r = 0; r < rows.length; r++) {
      final isHeader = r == 0;
      buffer.write('<w:tr>');
      final row = rows[r];
      for (int c = 0; c < row.length; c++) {
        final cellText = _escapeXml(row[c]);
        final bgColor = isHeader ? '1E3A8A' : (r % 2 == 1 ? 'F8FAFC' : 'FFFFFF');
        final textColor = isHeader ? 'FFFFFF' : '1F2937';
        final boldXml = isHeader ? '<w:b/><w:bCs/>' : '';

        buffer.write('<w:tc>');
        buffer.write('<w:tcPr>');
        buffer.write('<w:shd w:val="clear" w:color="auto" w:fill="$bgColor"/>');
        buffer.write('<w:tcMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tcMar>');
        buffer.write('</w:tcPr>');
        buffer.write('<w:p><w:r><w:rPr>$boldXml<w:color w:val="$textColor"/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr><w:t xml:space="preserve">$cellText</w:t></w:r></w:p>');
        buffer.write('</w:tc>');
      }
      buffer.write('</w:tr>');
    }
    buffer.write('</w:tbl>');
    return buffer.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
