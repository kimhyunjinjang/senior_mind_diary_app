import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 현재 로그인한 계정의 ownerUid를 해석
/// - 시니어: 나 자신
/// - 보호자: sharedWith == 내 uid 인 시니어 1명
Future<String?> resolveOwnerUid() async {
  final me = FirebaseAuth.instance.currentUser;
  if (me == null) return null;

  final meDoc = await FirebaseFirestore.instance.collection('users').doc(me.uid).get();
  final role = (meDoc.data() ?? const {})['role'] as String? ?? 'senior';

  if (role == 'guardian') {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('sharedWith', isEqualTo: me.uid)
        .limit(1)
        .get();
    return q.docs.isNotEmpty ? q.docs.first.id : null;
  } else {
    return me.uid;
  }
}

/// ownerUid의 일기 전체를 읽어서 날짜→{emotion, diary} 맵으로 반환
Future<Map<String, Map<String, String>>> loadEmotionDataFromFirestoreFor({
  required String ownerUid,
}) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .collection('diaries')
      .get();

  final result = <String, Map<String, String>>{};
  for (final doc in snap.docs) {
    final m = doc.data();
    result[doc.id] = {
      'emotion': m['emotion'] ?? '',
      'diary': m['note'] ?? '',
    };
  }
  return result;
}

/// (선택) 레거시 호환용: 기존 시그니처 유지, 내부에서 ownerUid를 해석해 호출
@Deprecated('Use loadEmotionDataFromFirestoreFor(ownerUid: ...) instead')
Future<Map<String, Map<String, String>>> loadEmotionDataFromFirestoreLegacy() async {
  final ownerUid = await resolveOwnerUid();
  if (ownerUid == null) return {};
  return loadEmotionDataFromFirestoreFor(ownerUid: ownerUid);
}

Future<void> saveEmotionAndNote({
  required String date, // 예: '2025-05-02'
  required String emotion, // 예: 'happy', 'neutral', 'sad'
  required String note, // 예: '산책을 해서 기분이 좋았어요'
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // 내 역할/권한 확인 (전역 globals 대신 users/{uid} 문서로 판단)
  final meDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final me = meDoc.data() ?? const {};
  final role = (me['role'] as String?) ?? 'senior';
  // 규칙이 "canWriteSelf == false 금지"라면 기본 true로 보고 false일 때만 막기
  final canWriteSelf = me['canWriteSelf'] != false;

  if (role == 'guardian' || !canWriteSelf) {
    // Firestore 규칙에서도 막히겠지만, 클라이언트에서도 가드
    throw StateError('Guardians cannot write diaries.');
  }

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('diaries')
      .doc(date)
      .set(
    {
      'emotion': emotion,
      'note': note,
      'date': date,
      'timestamp': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true), // 다른 필드 보존
  );
}

/// 과거 문서 중 date 필드가 비어있는 문서를 문서ID로 채워 넣는다.
/// 반환: 업데이트한 문서 수
Future<int> backfillDiaryDates({required String ownerUid}) async {
  final col = FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .collection('diaries');

  final snap = await col.get();
  int updated = 0;

  for (final d in snap.docs) {
    final data = d.data();
    final hasDate = (data['date'] as String?)?.isNotEmpty == true;
    if (!hasDate) {
      await d.reference.update({'date': d.id}); // ✅ 문서ID(YYYY-MM-DD)를 date로 채움
      updated++;
    }
  }
  return updated;
}