import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:filmsoz_studio/features/screenplay/document/block_type.dart';
import 'package:filmsoz_studio/features/screenplay/editor/controller/screenplay_editor_controller.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_block_widget.dart';
import 'package:filmsoz_studio/features/screenplay/editor/widgets/script_page_sheet.dart';
import 'package:filmsoz_studio/features/screenplay/navigator/scene_navigator.dart';
import 'package:filmsoz_studio/features/screenplay/toolbar/editor_toolbar.dart';

class EditorMainScreen extends StatefulWidget {
  const EditorMainScreen({super.key});

  @override
  State<EditorMainScreen> createState() => _EditorMainScreenState();
}

class _EditorMainScreenState extends State<EditorMainScreen> {
  final ScreenplayEditorController _controller = ScreenplayEditorController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const EditorToolbar(),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    () => _controller.saveDocument(),
              },
              child: Focus(
                autofocus: true,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Row(
                      children: [
                        SceneNavigator(
                          scenes: _controller.document.scenes,
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: Container(
                            color: const Color(0xFF1E1E1E),
                            child: Center(
                              child: SingleChildScrollView(
                                child: ScriptPageSheet(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: _controller.document.blocks
                                        .map(
                                          (block) => ScriptBlockWidget(
                                            block: block,
                                            onChanged: (text) =>
                                                _controller.updateBlockText(
                                                    block.id, text),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
