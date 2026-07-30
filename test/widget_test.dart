import 'package:filmsoz_studio/app/app.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/editor_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Filmsoz Studio открывает сценарный редактор',
    (WidgetTester tester) async {
      await tester.pumpWidget(const FilmnomaApp());
      await tester.pump();

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
