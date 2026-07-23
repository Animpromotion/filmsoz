import 'package:flutter/material.dart';

class ScriptPageSheet extends StatelessWidget {
  final Widget child;

  const ScriptPageSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 650, // Стандартная ширина страницы формата Letter/A4 в px
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.only(top: 72, bottom: 72, left: 90, right: 72),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
