import 'package:flutter_test/flutter_test.dart';

import 'package:turcoscore/main.dart';

void main() {
  testWidgets('ana ekran açılır ve alt menü görünür', (tester) async {
    await tester.pumpWidget(const TurcoScoreApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('TurcoScore'), findsOneWidget);
    expect(find.text('Maçlar'), findsOneWidget);
    expect(find.text('Ligler'), findsOneWidget);
    expect(find.text('Arama'), findsOneWidget);
  });
}
