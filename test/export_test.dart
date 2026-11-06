import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seak_scanner/core/database/models/document_model.dart';
import 'package:seak_scanner/core/services/export_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  final sampleDocs = [
    DocumentModel(
      id: 'doc-1',
      title: 'Invoice_ABC',
      createdAt: DateTime(2026, 11, 1, 10, 30),
      updatedAt: DateTime(2026, 11, 1, 10, 35),
      pageCount: 2,
      fileSizeBytes: 245000,
      isFavorite: true,
      ocrFullText: 'INVOICE #1024 Total: \$450.00 Paid in full',
    ),
    DocumentModel(
      id: 'doc-2',
      title: 'Contract_2026',
      createdAt: DateTime(2026, 11, 2, 14, 15),
      updatedAt: DateTime(2026, 11, 2, 14, 20),
      pageCount: 5,
      fileSizeBytes: 1250000,
      isFavorite: false,
      ocrFullText: 'Service Level Agreement between Company A and Company B',
    ),
  ];

  test('Export Document List to PDF test', () async {
    final pdfPath = await ExportDownloadService.instance.exportDocumentListToPdf(
      sampleDocs,
      title: 'Test Document List',
    );
    expect(pdfPath, isNotEmpty);
    final file = File(pdfPath);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(500));
  });

  test('Export Document List to Excel test', () async {
    final excelPath = await ExportDownloadService.instance.exportDocumentListToExcel(
      sampleDocs,
      title: 'Test_Excel_List',
    );
    expect(excelPath, isNotEmpty);
    final file = File(excelPath);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(500));
  });

  test('Export Document List to Word DOCX test', () async {
    final docxPath = await ExportDownloadService.instance.exportDocumentListToDocx(
      sampleDocs,
      title: 'Test_Docx_List',
    );
    expect(docxPath, isNotEmpty);
    final file = File(docxPath);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(500));
  });

  test('Export Document List to CSV test', () async {
    final csvPath = await ExportDownloadService.instance.exportDocumentListToCsv(
      sampleDocs,
      title: 'Test_Csv_List',
    );
    expect(csvPath, isNotEmpty);
    final file = File(csvPath);
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content.contains('Invoice_ABC'), isTrue);
    expect(content.contains('Contract_2026'), isTrue);
  });

  test('Export Text Content to multiple formats test', () async {
    const text = 'Line 1: Item Apple \$1.00\nLine 2: Item Banana \$2.00\nTotal: \$3.00';

    final pdfPath = await ExportDownloadService.instance.exportTextContent(
      text: text,
      title: 'Receipt_Text',
      format: ExportFormat.pdf,
    );
    expect(await File(pdfPath).exists(), isTrue);

    final docxPath = await ExportDownloadService.instance.exportTextContent(
      text: text,
      title: 'Receipt_Text',
      format: ExportFormat.docx,
    );
    expect(await File(docxPath).exists(), isTrue);

    final xlsxPath = await ExportDownloadService.instance.exportTextContent(
      text: text,
      title: 'Receipt_Text',
      format: ExportFormat.excel,
    );
    expect(await File(xlsxPath).exists(), isTrue);

    final csvPath = await ExportDownloadService.instance.exportTextContent(
      text: text,
      title: 'Receipt_Text',
      format: ExportFormat.csv,
    );
    expect(await File(csvPath).exists(), isTrue);
  });

  test('Download image test', () async {
    // Create dummy image file
    final tempDir = Directory.systemTemp.createTempSync('img_test');
    final dummyImg = File('${tempDir.path}/test_image.jpg');
    await dummyImg.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46]);

    final downloadedPath = await ExportDownloadService.instance.downloadPageImage(
      imagePath: dummyImg.path,
      documentTitle: 'Scanned Document',
      pageIndex: 0,
    );

    expect(downloadedPath, isNotEmpty);
    final downloadedFile = File(downloadedPath);
    expect(await downloadedFile.exists(), isTrue);
    expect(await downloadedFile.length(), equals(10));
  });
}
