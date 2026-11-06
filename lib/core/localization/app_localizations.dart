import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('km'),
  ];

  String translate(String key) {
    final languageCode = locale.languageCode;
    final dict = _localizedValues[languageCode] ?? _localizedValues['en']!;
    return dict[key] ?? _localizedValues['en']![key] ?? key;
  }

  // Shorthand getter method
  String t(String key) => translate(key);

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // General
      'appName': 'SeakScanner',
      'appTagline': 'Smart Document Scanner & PDF Manager',
      'searchHint': 'Search documents or text...',
      'save': 'Save',
      'cancel': 'Cancel',
      'done': 'Done',
      'delete': 'Delete',
      'edit': 'Edit',
      'share': 'Share',
      'rename': 'Rename',
      'viewAll': 'View All',
      'pages': 'Pages',
      'page': 'Page',
      'close': 'Close',
      'confirm': 'Confirm',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'retake': 'Retake',
      'continue': 'Continue',
      'apply': 'Apply',
      'reset': 'Reset',
      'restore': 'Restore',
      'deletePermanently': 'Delete Permanently',
      'download': 'Download',
      'downloadImage': 'Download Image',
      'downloadCurrentImage': 'Download Current Page Image',
      'downloadAllImages': 'Download All Page Images',
      'downloadList': 'Download List to File',
      'downloadSelected': 'Download Selected',
      'exportAsPdf': 'PDF Document (.pdf)',
      'exportAsExcel': 'Excel Spreadsheet (.xlsx)',
      'exportAsDocx': 'Word Document (.docx)',
      'exportAsCsv': 'CSV File (.csv)',
      'exportFormatTitle': 'Download Options',
      'imageSavedSuccess': 'Image saved to Downloads folder',
      'fileSavedSuccess': 'File saved to Downloads folder',
      'open': 'Open',

      // Navigation
      'navHome': 'Home',
      'navDocuments': 'Documents',
      'navScan': 'Scan',
      'navTools': 'Tools',
      'navSettings': 'Settings',

      // Home
      'quickScan': 'Quick Scan',
      'importGallery': 'Import Images',
      'recentFiles': 'Recent Files',
      'myFolders': 'My Folders',
      'favorites': 'Favorites',
      'allDocuments': 'All Documents',
      'totalScanned': 'Total Scanned',
      'quickTools': 'Quick Tools',
      'noRecentDocs': 'No recent documents yet',
      'noRecentDocsSubtitle': 'Tap the scan button or import from gallery to start scanning.',
      'newFolder': 'New Folder',
      'folderName': 'Folder Name',
      'create': 'Create',

      // Tools Cards
      'toolScan': 'Scan',
      'toolAddText': 'Add Text',
      'toolOCR': 'OCR Text',
      'toolMarkUp': 'Mark Up',
      'toolHide': 'Hide/Redact',
      'tooleSign': 'eSign',
      'toolImages': 'Images to PDF',
      'toolMerge': 'Merge PDF',
      'toolSplit': 'Split PDF',
      'toolCompress': 'Compress',

      // Scanner
      'autoCapture': 'Auto',
      'manualCapture': 'Manual',
      'flashOn': 'Flash On',
      'flashOff': 'Flash Off',
      'flashAuto': 'Flash Auto',
      'grid': 'Grid',
      'capturingHoldSteady': 'Capturing... hold steady',
      'documentDetected': 'Document detected',
      'noDocumentFound': 'Searching for document...',
      'modeDocument': 'Document',
      'modeIDCard': 'ID Card',
      'modeWhiteboard': 'Whiteboard',
      'modeBook': 'Book',
      'modeBusinessCard': 'Business Card',

      // Crop & Perspective
      'cropTitle': 'Adjust Borders',
      'cropInstruction': 'Drag the handles to adjust the borders. You can also do this later using the crop tool.',
      'rotateLeft': 'Rotate Left',
      'rotateRight': 'Rotate Right',
      'autoDetect': 'Auto Detect',
      'fullImage': 'Full Image',

      // Enhancement Filters
      'filterOriginal': 'Original',
      'filterAuto': 'Auto Enhance',
      'filterMagic': 'Magic Color',
      'filterBW': 'B & W',
      'filterGrayscale': 'Grayscale',
      'filterHighContrast': 'High Contrast',
      'filterSharpen': 'Sharpen',
      'brightness': 'Brightness',
      'contrast': 'Contrast',
      'filterPreview': 'Filter Preview',

      // Multi-Page Scanner Preview
      'multiPageTitle': 'Scanned Pages',
      'addPage': 'Add Page',
      'reorderPages': 'Reorder Pages',
      'deletePage': 'Delete Page',
      'generatePdf': 'Generate PDF',
      'documentName': 'Document Name',

      // OCR
      'ocrTitle': 'Text Recognition',
      'ocrExtracting': 'Extracting text from document...',
      'ocrResult': 'Extracted Text',
      'ocrLanguage': 'OCR Language',
      'ocrLangEnglish': 'English',
      'ocrLangKhmer': 'Khmer (ភាសាខ្មែរ)',
      'ocrLangMixed': 'Khmer + English',
      'copyText': 'Copy Text',
      'copiedToClipboard': 'Text copied to clipboard!',
      'exportTxt': 'Export as TXT',
      'searchInText': 'Search in text...',
      'noTextFound': 'No text detected in this page.',

      // PDF Tools & Viewer
      'pdfViewer': 'PDF Viewer',
      'printPdf': 'Print Document',
      'sharePdf': 'Share PDF',
      'shareImages': 'Share Images (JPG)',
      'pdfDetails': 'PDF Details',
      'fileSize': 'File Size',
      'createdDate': 'Created',
      'signatureTitle': 'Add Signature',
      'clearSignature': 'Clear',
      'saveSignature': 'Insert Signature',
      'signInstruction': 'Draw your signature in the box below',
      'mergePdfTitle': 'Merge PDF Files',
      'selectPdfsToMerge': 'Select 2 or more PDFs to merge',
      'splitPdfTitle': 'Split PDF',
      'compressPdfTitle': 'Compress PDF',
      'compressionLow': 'Low Compression (High Quality)',
      'compressionMedium': 'Medium Compression (Balanced)',
      'compressionHigh': 'High Compression (Small Size)',

      // Document Management
      'moveToFolder': 'Move to Folder',
      'selectFolder': 'Select Folder',
      'unfiled': 'Unfiled',
      'sortBy': 'Sort By',
      'sortDateNewest': 'Date (Newest first)',
      'sortDateOldest': 'Date (Oldest first)',
      'sortNameAZ': 'Name (A to Z)',
      'sortNameZA': 'Name (Z to A)',
      'sortSize': 'Size (Largest first)',
      'moveToTrash': 'Move to Trash',
      'trashTitle': 'Recently Deleted',
      'trashEmpty': 'Trash is empty',
      'trashNote': 'Documents in trash can be restored or deleted permanently.',
      'batchSelect': 'Select Multiple',
      'itemsSelected': 'items selected',

      // Security
      'securityTitle': 'Security & App Lock',
      'enableAppLock': 'Enable Passcode Lock',
      'useBiometrics': 'Unlock with Fingerprint / Face ID',
      'changePasscode': 'Change Passcode',
      'enterPasscode': 'Enter Passcode',
      'confirmPasscode': 'Confirm Passcode',
      'passcodeIncorrect': 'Incorrect passcode. Try again.',
      'passcodeMatched': 'Passcode enabled successfully.',
      'passcodesDoNotMatch': 'Passcodes do not match.',
      'securitySubtitle': 'Protect your sensitive scanned documents on this device.',

      // Settings
      'settingsTitle': 'Settings',
      'prefTheme': 'Appearance Theme',
      'themeLight': 'Light Mode',
      'themeDark': 'Dark Mode',
      'themeSystem': 'System Default',
      'prefLanguage': 'Application Language',
      'defaultPageSize': 'Default PDF Page Size',
      'defaultScanQuality': 'Default Scan Resolution',
      'storageUsage': 'Storage Used',
      'clearCache': 'Clear Image Cache',
      'cacheCleared': 'Image cache cleaned successfully.',
      'aboutApp': 'About SeakScanner',
      'version': 'Version',
      'privacyStatement': '100% On-Device Privacy Guaranteed',
      'privacyDetails': 'All scanning, cropping, enhancement, and OCR are processed locally on your phone. No documents are uploaded to cloud servers without your explicit action.',
    },
    'km': {
      // General
      'appName': 'ស៊ាក ស្កេនន័រ (SeakScanner)',
      'appTagline': 'កម្មវិធីស្កេនឯកសារវៃឆ្លាត និងគ្រប់គ្រង PDF',
      'searchHint': 'ស្វែងរកឯកសារ ឬអត្ថបទ...',
      'save': 'រក្សាទុក',
      'cancel': 'បោះបង់',
      'done': 'រួចរាល់',
      'delete': 'លុប',
      'edit': 'កែប្រែ',
      'share': 'ចែករំលែក',
      'rename': 'ប្តូរឈ្មោះ',
      'viewAll': 'មើលទាំងអស់',
      'pages': 'ទំព័រ',
      'page': 'ទំព័រ',
      'close': 'បិទ',
      'confirm': 'យល់ព្រម',
      'error': 'កំហុស',
      'success': 'ជោគជ័យ',
      'loading': 'កំពុងដំណើរការ...',
      'retake': 'ថតឡើងវិញ',
      'continue': 'បន្ត',
      'apply': 'អនុវត្ត',
      'reset': 'កំណត់ឡើងវិញ',
      'restore': 'ស្តារឡើងវិញ',
      'deletePermanently': 'លុបជាអចិន្ត្រៃយ៍',
      'download': 'ទាញយក',
      'downloadImage': 'ទាញយករូបភាព',
      'downloadCurrentImage': 'ទាញយករូបភាពទំព័របច្ចុប្បន្ន',
      'downloadAllImages': 'ទាញយករូបភាពគ្រប់ទំព័រ',
      'downloadList': 'ទាញយកបញ្ជីជាឯកសារ',
      'downloadSelected': 'ទាញយកបញ្ជីដែលបានជ្រើស',
      'exportAsPdf': 'ឯកសារ PDF (.pdf)',
      'exportAsExcel': 'តារាង Excel (.xlsx)',
      'exportAsDocx': 'ឯកសារ Word (.docx)',
      'exportAsCsv': 'ឯកសារ CSV (.csv)',
      'exportFormatTitle': 'ជម្រើសទាញយកឯកសារ',
      'imageSavedSuccess': 'រូបភាពត្រូវបានរក្សាទុកក្នុង Downloads',
      'fileSavedSuccess': 'ឯកសារត្រូវបានរក្សាទុកក្នុង Downloads',
      'open': 'បើក',

      // Navigation
      'navHome': 'ទំព័រដើម',
      'navDocuments': 'ឯកសារ',
      'navScan': 'ស្កេន',
      'navTools': 'ឧបករណ៍',
      'navSettings': 'ការកំណត់',

      // Home
      'quickScan': 'ស្កេនរហ័ស',
      'importGallery': 'នាំចូលរូបភាព',
      'recentFiles': 'ឯកសារថ្មីៗ',
      'myFolders': 'ថតឯកសាររបស់ខ្ញុំ',
      'favorites': 'ឯកសារពេញចិត្ត',
      'allDocuments': 'ឯកសារទាំងអស់',
      'totalScanned': 'ស្កេនសរុប',
      'quickTools': 'ឧបករណ៍រហ័ស',
      'noRecentDocs': 'មិនទាន់មានឯកសារនៅឡើយទេ',
      'noRecentDocsSubtitle': 'ចុចប៊ូតុងស្កេន ឬនាំចូលរូបភាពពីវិចិត្រសាលដើម្បីចាប់ផ្តើម។',
      'newFolder': 'ថតឯកសារថ្មី',
      'folderName': 'ឈ្មោះថត',
      'create': 'បង្កើត',

      // Tools Cards
      'toolScan': 'ស្កេន',
      'toolAddText': 'បន្ថែមអក្សរ',
      'toolOCR': 'បំប្លែងជាអក្សរ (OCR)',
      'toolMarkUp': 'គូសចំណាំ',
      'toolHide': 'បិទបាំង',
      'tooleSign': 'ហត្ថលេខា',
      'toolImages': 'រូបភាពទៅ PDF',
      'toolMerge': 'បញ្ចូល PDF គ្នា',
      'toolSplit': 'បំបែក PDF',
      'toolCompress': 'បង្រួមទំហំ PDF',

      // Scanner
      'autoCapture': 'ស្វ័យប្រវត្តិ',
      'manualCapture': 'ដោយដៃ',
      'flashOn': 'បើកពិល',
      'flashOff': 'បិទពិល',
      'flashAuto': 'ពិលស្វ័យប្រវត្តិ',
      'grid': 'បន្ទាត់ក្រឡា',
      'capturingHoldSteady': 'កំពុងចាប់យករូបភាព... សូមកាន់ឱ្យនឹង',
      'documentDetected': 'រកឃើញគែមក្រដាសឯកសារ',
      'noDocumentFound': 'កំពុងស្វែងរកឯកសារ...',
      'modeDocument': 'ឯកសារទូទៅ',
      'modeIDCard': 'អត្តសញ្ញាណប័ណ្ណ',
      'modeWhiteboard': 'ក្តារខៀន',
      'modeBook': 'សៀវភៅ',
      'modeBusinessCard': 'នាមប័ណ្ណ',

      // Crop & Perspective
      'cropTitle': 'កែសម្រួលគែមឯកសារ',
      'cropInstruction': 'ទាញជ្រុងទាំង៤ ដើម្បីតម្រឹមកម្រាស់ក្រដាសឱ្យត្រង់។',
      'rotateLeft': 'បង្វិលឆ្វេង',
      'rotateRight': 'បង្វិលស្តាំ',
      'autoDetect': 'ចាប់ជ្រុងស្វ័យប្រវត្តិ',
      'fullImage': 'រូបភាពពេញ',

      // Enhancement Filters
      'filterOriginal': 'រូបដើម',
      'filterAuto': 'កែលម្អស្វ័យប្រវត្តិ',
      'filterMagic': 'ពណ៌វេទមន្ត (Magic)',
      'filterBW': 'ស និង ខ្មៅ',
      'filterGrayscale': 'ស្រមោលប្រផេះ',
      'filterHighContrast': 'កម្រិតពណ៌ច្បាស់',
      'filterSharpen': 'សម្រួចរូបភាព',
      'brightness': 'ពន្លឺ',
      'contrast': 'កម្រិតពណ៌ខុសគ្នា',
      'filterPreview': 'ទិដ្ឋភាពមុនរក្សាទុក',

      // Multi-Page Scanner Preview
      'multiPageTitle': 'ទំព័រដែលបានស្កេន',
      'addPage': 'បន្ថែមទំព័រ',
      'reorderPages': 'តម្រៀបទំព័រឡើងវិញ',
      'deletePage': 'លុបទំព័រនេះ',
      'generatePdf': 'បង្កើតជា PDF',
      'documentName': 'ឈ្មោះឯកសារ',

      // OCR
      'ocrTitle': 'ការស្រង់អត្ថបទ (OCR)',
      'ocrExtracting': 'កំពុងស្រង់អត្ថបទចេញពីរូបភាព...',
      'ocrResult': 'អត្ថបទដែលស្រង់បាន',
      'ocrLanguage': 'ភាសា OCR',
      'ocrLangEnglish': 'ភាសាអង់គ្លេស',
      'ocrLangKhmer': 'ភាសាខ្មែរ',
      'ocrLangMixed': 'ខ្មែរ + អង់គ្លេស',
      'copyText': 'ចម្លងអត្ថបទ',
      'copiedToClipboard': 'បានចម្លងអត្ថបទរួចរាល់!',
      'exportTxt': 'ទាញយកជាឯកសារ TXT',
      'searchInText': 'ស្វែងរកពាក្យក្នុងអត្ថបទ...',
      'noTextFound': 'មិនឃើញមានអត្ថបទក្នុងទំព័រនេះទេ។',

      // PDF Tools & Viewer
      'pdfViewer': 'កម្មវិធីមើល PDF',
      'printPdf': 'បោះពុម្ពឯកសារ',
      'sharePdf': 'ចែករំលែក PDF',
      'shareImages': 'ចែករំលែករូបភាព (JPG)',
      'pdfDetails': 'ព័ត៌មានលម្អិត PDF',
      'fileSize': 'ទំហំឯកសារ',
      'createdDate': 'កាលបរិច្ឆេទបង្កើត',
      'signatureTitle': 'បន្ថែមហត្ថលេខា',
      'clearSignature': 'សម្អាត',
      'saveSignature': 'បញ្ចូលហត្ថលេខា',
      'signInstruction': 'គូរហត្ថលេខារបស់អ្នកក្នុងប្រអប់ខាងក្រោម',
      'mergePdfTitle': 'បញ្ចូលឯកសារ PDF ចូលគ្នា',
      'selectPdfsToMerge': 'ជ្រើសរើសឯកសារ PDF ចាប់ពី ២ ឡើងទៅ',
      'splitPdfTitle': 'បំបែកទំព័រ PDF',
      'compressPdfTitle': 'បង្រួមទំហំឯកសារ PDF',
      'compressionLow': 'បង្រួមតិច (គុណភាពខ្ពស់)',
      'compressionMedium': 'បង្រួមមធ្យម (សមរម្យ)',
      'compressionHigh': 'បង្រួមខ្លាំង (ទំហំតូចបំផុត)',

      // Document Management
      'moveToFolder': 'ផ្លាស់ទីទៅថត',
      'selectFolder': 'ជ្រើសរើសថត',
      'unfiled': 'ទូទៅ',
      'sortBy': 'តម្រៀបតាម',
      'sortDateNewest': 'កាលបរិច្ឆេទ (ថ្មីទៅចាស់)',
      'sortDateOldest': 'កាលបរិច្ឆេទ (ចាស់ទៅថ្មី)',
      'sortNameAZ': 'ឈ្មោះ (A ទៅ Z)',
      'sortNameZA': 'ឈ្មោះ (Z ទៅ A)',
      'sortSize': 'ទំហំឯកសារ (ធំទៅតូច)',
      'moveToTrash': 'ផ្លាស់ទីទៅធុងសម្រាម',
      'trashTitle': 'ឯកសារដែលបានលុប',
      'trashEmpty': 'ធុងសម្រាមទទេ',
      'trashNote': 'ឯកសារក្នុងធុងសម្រាមអាចស្តារឡើងវិញ ឬលុបចោលជាអចិន្ត្រៃយ៍បាន។',
      'batchSelect': 'ជ្រើសរើសច្រើន',
      'itemsSelected': 'ឯកសារបានជ្រើសរើស',

      // Security
      'securityTitle': 'សុវត្ថិភាព និងចាក់សោកម្មវិធី',
      'enableAppLock': 'បើកការចាក់សោដោយលេខសម្ងាត់',
      'useBiometrics': 'ដោះសោដោយស្កេនមេដៃ / ផ្ទៃមុខ',
      'changePasscode': 'ប្តូរលេខកូដសម្ងាត់',
      'enterPasscode': 'បញ្ចូលលេខកូដសម្ងាត់',
      'confirmPasscode': 'បញ្ជាក់លេខកូដសម្ងាត់ម្តងទៀត',
      'passcodeIncorrect': 'លេខកូដមិនត្រឹមត្រូវទេ។ សូមព្យាយាមម្តងទៀត។',
      'passcodeMatched': 'បានបើកដំណើរការចាក់សោដោយជោគជ័យ។',
      'passcodesDoNotMatch': 'លេខកូដទាំងពីរមិនដូចគ្នាទេ។',
      'securitySubtitle': 'ការពារឯកសារសម្ងាត់របស់អ្នកនៅលើឧបករណ៍នេះ។',

      // Settings
      'settingsTitle': 'ការកំណត់',
      'prefTheme': 'រចនាបថផ្ទៃកម្មវិធី',
      'themeLight': 'ពន្លឺធម្មតា (Light)',
      'themeDark': 'ផ្ទៃងងឹត (Dark)',
      'themeSystem': 'តាមប្រព័ន្ធទូរស័ព្ទ',
      'prefLanguage': 'ភាសាកម្មវិធី',
      'defaultPageSize': 'ទំហំទំព័រ PDF ដើម',
      'defaultScanQuality': 'កម្រិតគុណភាពរូបភាព',
      'storageUsage': 'ទំហំផ្ទុកដែលបានប្រើ',
      'clearCache': 'សម្អាតទិន្នន័យបណ្តោះអាសន្ន',
      'cacheCleared': 'បានសម្អាតទិន្នន័យបណ្តោះអាសន្នរួចរាល់។',
      'aboutApp': 'អំពី SeakScanner',
      'version': 'ជំនាន់',
      'privacyStatement': 'ឯកជនភាព ១០០% នៅលើឧបករណ៍របស់អ្នក',
      'privacyDetails': 'រាល់ការស្កេន កាត់តម្រឹម កែលម្អរូបភាព និងការស្រង់អក្សរ OCR ដំណើរការលើទូរស័ព្ទរបស់អ្នកផ្ទាល់ ដោយមិនបង្ហោះទៅកាន់ Cloud ឡើយ។',
    },
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'km'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).translate(key);
}

