import 'package:flutter/material.dart';

class ScriptPageSheet extends StatelessWidget {
  const ScriptPageSheet({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 812,
      constraints: const BoxConstraints(minHeight: 1054),
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.fromLTRB(82, 80, 82, 100),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
