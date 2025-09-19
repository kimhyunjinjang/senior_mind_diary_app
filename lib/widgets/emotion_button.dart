import 'package:flutter/material.dart';
import '../utils.dart';

class EmotionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool selected;

  const EmotionButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: selected
              ? color.withAlphaFraction(1.0)
              : color.withAlphaFraction(0.6),
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: Colors.black, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}