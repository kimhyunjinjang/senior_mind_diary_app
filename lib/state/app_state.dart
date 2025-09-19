import 'package:flutter/foundation.dart';

typedef EmotionMap = Map<String, Map<String, String>>;
final ValueNotifier<EmotionMap> emotionDataNotifier = ValueNotifier<EmotionMap>({});
