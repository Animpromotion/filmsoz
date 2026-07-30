import 'package:filmsoz_studio/app/app.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/editor_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Filmsoz Studio открывает сценарный редактор',
    (WidgetTester tester) async {
      // Filmsoz — настольное приложение.
      // Стандартное тестовое окно Flutter 800×600 слишком узкое
      // для полной панели инструментов.
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const FilmnomaApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byType(EditorMainScreen),
        findsOneWidget,
      );

      expect(
        find.byType(TextField),
        findsWidgets,
      );
    },
  );
}
