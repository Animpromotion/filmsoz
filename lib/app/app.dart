import 'package:flutter/material.dart';
import 'package:filmsoz_studio/app/theme.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/editor_main_screen.dart';

class FilmnomaApp extends StatelessWidget {
  const FilmnomaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Филмнома v0.1',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const EditorMainScreen(),
    );
  }
}
