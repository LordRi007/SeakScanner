import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args[0] : 'assets/icons/app_logo.png';
  final file = File(inputPath);
  if (!file.existsSync()) {
    print('Master icon not found at: $inputPath');
    return;
  }

  print('Reading master icon from $inputPath...');
  final masterBytes = file.readAsBytesSync();
  final master = img.decodeImage(masterBytes);
  if (master == null) {
    print('Failed to decode master image');
    return;
  }

  print('Master image size: ${master.width} x ${master.height}');

  // 1. Android Mipmap Sizes
  final androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in androidSizes.entries) {
    final folder = 'android/app/src/main/res/${entry.key}';
    Directory(folder).createSync(recursive: true);
    final size = entry.value;

    // Standard square icon
    final resized = img.copyResize(master, width: size, height: size, interpolation: img.Interpolation.cubic);
    File('$folder/ic_launcher.png').writeAsBytesSync(img.encodePng(resized));

    // Circular/round icon
    final round = _createCircularIcon(resized);
    File('$folder/ic_launcher_round.png').writeAsBytesSync(img.encodePng(round));
    print('Generated Android $folder: ${size}x$size');
  }

  // 2. Android Adaptive Icon Foreground (432x432 with padding)
  final fgSize = 432;
  final fgContentSize = 280; // 65% safe zone
  final fgResized = img.copyResize(master, width: fgContentSize, height: fgContentSize, interpolation: img.Interpolation.cubic);
  final fgCanvas = img.Image(width: fgSize, height: fgSize, numChannels: 4);
  // Center content
  final padX = (fgSize - fgContentSize) ~/ 2;
  final padY = (fgSize - fgContentSize) ~/ 2;
  img.compositeImage(fgCanvas, fgResized, dstX: padX, dstY: padY);

  final drawableDir = 'android/app/src/main/res/drawable';
  Directory(drawableDir).createSync(recursive: true);
  File('$drawableDir/ic_launcher_foreground.png').writeAsBytesSync(img.encodePng(fgCanvas));
  print('Generated Android adaptive foreground (432x432)');

  // 3. Android Adaptive XML definitions
  final v26Dir = 'android/app/src/main/res/mipmap-anydpi-v26';
  Directory(v26Dir).createSync(recursive: true);

  File('$v26Dir/ic_launcher.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''');

  File('$v26Dir/ic_launcher_round.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
''');

  // Background color definition (Deep vibrant royal blue #1E3A8A)
  final valuesDir = 'android/app/src/main/res/values';
  Directory(valuesDir).createSync(recursive: true);
  File('$valuesDir/ic_launcher_background.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1E3A8A</color>
</resources>
''');

  // 4. iOS Icons
  final iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  Directory(iosDir).createSync(recursive: true);

  final iosSizes = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };

  for (final entry in iosSizes.entries) {
    final size = entry.value;
    final resized = img.copyResize(master, width: size, height: size, interpolation: img.Interpolation.cubic);
    File('$iosDir/${entry.key}').writeAsBytesSync(img.encodePng(resized));
    print('Generated iOS ${entry.key}: ${size}x$size');
  }

  print('All Android and iOS icons successfully generated!');
}

img.Image _createCircularIcon(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  final cx = (src.width - 1) / 2.0;
  final cy = (src.height - 1) / 2.0;
  final r = min(cx, cy);

  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist <= r) {
        out.setPixel(x, y, src.getPixel(x, y));
      }
    }
  }
  return out;
}
