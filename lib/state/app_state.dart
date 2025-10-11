import 'package:flutter/foundation.dart';

typedef EmotionMap = Map<String, Map<String, dynamic>>;
final ValueNotifier<EmotionMap> emotionDataNotifier = ValueNotifier<EmotionMap>({});
