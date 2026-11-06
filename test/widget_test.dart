import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:seak_scanner/core/localization/app_localizations.dart';
import 'package:seak_scanner/core/services/perspective_service.dart';
import 'package:seak_scanner/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DocumentQuad default normalized initialization', () {
    final quad = DocumentQuad.defaultNormalized(inset: 0.1);
    expect(quad.topLeft, const Offset(0.1, 0.1));
    expect(quad.topRight, const Offset(0.9, 0.1));
    expect(quad.bottomRight, const Offset(0.9, 0.9));
    expect(quad.bottomLeft, const Offset(0.1, 0.9));
    expect(quad.points.length, 4);
  });

  test('PerspectiveService computeOutputSize and warp test', () {
    final quad = DocumentQuad.defaultNormalized(inset: 0.1).scale(100, 100);
    final size = PerspectiveService.computeOutputSize(quad);
    expect(size.width, greaterThan(50));
    expect(size.height, greaterThan(50));

    // Create a 100x100 dummy image
    final src = img.Image(width: 100, height: 100);
    img.fill(src, color: img.ColorRgb8(255, 255, 255));

    final warped = PerspectiveService.warpPerspective(src, quad);
    expect(warped.width, greaterThan(0));
    expect(warped.height, greaterThan(0));
  });

  test('AppLocalizations translation test', () {
    final enL10n = AppLocalizations(const Locale('en'));
    expect(enL10n.t('appName'), 'SeakScanner');
    expect(enL10n.t('toolScan'), 'Scan');

    final kmL10n = AppLocalizations(const Locale('km'));
    expect(kmL10n.t('toolScan'), 'ស្កេន');
  });

  testWidgets('SeakScannerApp renders splash screen without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SeakScannerApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
