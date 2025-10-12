import 'package:flutter/material.dart';
import '../utils.dart';

class EmotionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool selected;
  final TextStyle? labelStyle;

  const EmotionButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.labelStyle,
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
          /*mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14)),*/
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          const SizedBox(height: 2), // 살짝 상단 여유
          const SizedBox(height: 0), // 필요시 조정
          Text(
            emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 6), // (기존 8 → 6) 라벨 공간 확보
          Text(
            label,
            textAlign: TextAlign.center,           // 가운데 정렬
            maxLines: 2,                            // 2줄까지 허용(‘기분 안 좋음’ 대응)
            overflow: TextOverflow.ellipsis,        // 넘치면 말줄임
            softWrap: true,
            style: const TextStyle(
              fontSize: 18,                         // ★ 글자 키움(권장 20~22)
              height: 1.3,                          // 줄간격
            ),
          ),
          const SizedBox(height: 4), // 하단 숨쉬기
          ],
        ),
      ),
    );
  }
}