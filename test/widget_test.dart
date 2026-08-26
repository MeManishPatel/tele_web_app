import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tele_web_app/screens/shell.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const TelegramSpinWinApp());
    await tester.pumpAndSettle();
  }

  testWidgets('home screen loads on iPhone-sized Telegram viewport',
      (tester) async {
    await pumpApp(tester, const Size(390, 844));

    expect(find.textContaining('Hi,'), findsOneWidget);
    expect(find.text('Launch Spin & Win'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });

  testWidgets('layout flexes on compact Mini App viewport without overflow',
      (tester) async {
    await pumpApp(tester, const Size(320, 560));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Hi,'), findsOneWidget);
    expect(find.text('Launch Spin & Win'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.casino_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Gaming Arena'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Master Wallet'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Player Profile'), findsOneWidget);
  });
}
