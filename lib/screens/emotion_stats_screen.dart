import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pie_chart/pie_chart.dart';

// 👇 아래 경로는 네 프로젝트 구조에 맞게 조정
import '../utils.dart';
import '../services/emotion_storage.dart';

class EmotionStatsScreen extends StatefulWidget {
  const EmotionStatsScreen({super.key});

  @override
  State<EmotionStatsScreen> createState() => _EmotionStatsScreenState();
}

class _EmotionStatsScreenState extends State<EmotionStatsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('감정 통계')),
      body: FutureBuilder<String?>(
        // ownerUid만 한 번 비동기로 resolve
        future: resolveOwnerUid(),
        builder: (context, uidSnap) {
          if (uidSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ownerUid = uidSnap.data;
          if (ownerUid == null || ownerUid.isEmpty) {
            return const Center(child: Text('연결된 시니어가 없습니다.'));
          }

          final stream = FirebaseFirestore.instance
              .collection('users')
              .doc(ownerUid)
              .collection('diaries')
              .orderBy('date', descending: true)
              .limit(120)
              .snapshots(includeMetadataChanges: true); // 🔑

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData) {
                return const Center(child: Text('데이터가 없습니다.'));
              }

              final docs = snap.data!.docs;

              // 집계
              final dataMap = <String, double>{
                '😊 기분 좋음': 0,
                '😐 보통': 0,
                '😞 기분 안 좋음': 0,
              };
              for (final d in docs) {
                final e = (d.data()['emotion'] as String?) ?? '보통';
                if (e == '기분 좋음') {
                  dataMap['😊 기분 좋음'] = dataMap['😊 기분 좋음']! + 1;
                } else if (e == '보통') {
                  dataMap['😐 보통'] = dataMap['😐 보통']! + 1;
                } else if (e == '기분 안 좋음') {
                  dataMap['😞 기분 안 좋음'] = dataMap['😞 기분 안 좋음']! + 1;
                }
              }

              final total = dataMap.values.fold<double>(0, (a, b) => a + b);
              if (total == 0) {
                return const Center(
                  child: Text('아직 감정 기록이 없어요 😢', style: TextStyle(fontSize: 18)),
                );
              }

              return Center(
                child: PieChart(
                  dataMap: dataMap,
                  animationDuration: const Duration(milliseconds: 800),
                  chartRadius: MediaQuery.of(context).size.width / 1.5,
                  chartType: ChartType.disc,
                  legendOptions: const LegendOptions(
                    showLegends: true,
                    legendPosition: LegendPosition.bottom,
                    legendTextStyle: TextStyle(fontSize: 16),
                  ),
                  chartValuesOptions: const ChartValuesOptions(
                    showChartValuesInPercentage: true,
                    showChartValues: true,
                    decimalPlaces: 0,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}