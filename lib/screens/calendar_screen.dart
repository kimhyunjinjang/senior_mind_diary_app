import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'account_register_screen.dart';
import 'search_diary_screen.dart';       // ← 네 프로젝트 경로에 맞게 조정
import 'emotion_stats_screen.dart';      // ← 경로 조정
import 'emotion_input_screen.dart';      // ← 경로 조정
import '../utils.dart';                  // navigateReset, formatDate, isBeforeToday 등 (경로 조정)
import '../state/app_state.dart';
import '../services/emotion_storage.dart';
import 'dart:math' as math;
import 'my_invite_code_screen.dart';
import 'dart:async';
import 'invite_code_input_screen.dart';
import 'delete_account_screen.dart';

// ✅ 외부 전역: emotionDataNotifier (Map<String, Map<String,String>>)가 있다고 가정
//   예: final emotionDataNotifier = ValueNotifier<Map<String, Map<String, String>>>({});

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // --- 로컬 헬퍼(이 파일 안에서만 사용) ---
  bool _isBeforeToday(DateTime d) {
    final now = DateTime.now();
    final a = DateTime(d.year, d.month, d.day);
    final b = DateTime(now.year, now.month, now.day);
    return a.isBefore(b);
  }

  bool _isSameOrBeforeToday(DateTime d) {
    final now = DateTime.now();
    final a = DateTime(d.year, d.month, d.day);
    final b = DateTime(now.year, now.month, now.day);
    return a.isBefore(b) || a.isAtSameMomentAs(b);
  }

  // ---------- 상태 ----------
  String? _ownerUid;        // 시니어면 내 uid, 보호자면 연결된 시니어 uid
  String? _myRole;          // 'senior' | 'guardian'
  bool _linked = false;     // 보호자: 연결 유무 / 시니어: sharedWith 존재 유무

  // UI 상태
  String _mostFrequentEmotion = '보통';
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  String? _viewingEmotion;
  String? _viewingDiary;

  // 로딩/오류
  bool _resolving = true;
  String? _error;

  // === 달력 고정치(예전 느낌) ===
  static const double _kRowHeight = 56.0;   // 셀
  static const double _kDowHeight = 24.0;   // 요일줄

  void _goPrevMonth() {
    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
    setState(() {});
  }

  void _goNextMonth() {
    _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
    setState(() {});
  }

  String _monthTitle(DateTime d) => '${d.year}년 ${d.month}월';
  StreamSubscription? _guardianSub;

  // ---------- 라이프사이클 ----------
  @override
  void initState() {
    super.initState();
    _resolveOwnerAndLink();
    // 감정 요약(최빈값) 실시간 반영
    WidgetsBinding.instance.addPostFrameCallback((_) {
      emotionDataNotifier.addListener(_onEmotionDataChanged);
    });
  }

  @override
  void dispose() {
    emotionDataNotifier.removeListener(_onEmotionDataChanged);
    _guardianSub?.cancel();
    _guardianSub = null;
    super.dispose();
  }

  void _setupGuardianLinkListener() {
    // 보호자 모드일 때만
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    _guardianSub = FirebaseFirestore.instance
        .collection('users')
        .where('sharedWith', isEqualTo: myUid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        // 공유 해제 처리
        setState(() {
          _linked = false;
          _ownerUid = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시니어가 공유를 해제했습니다.')),
        );
      } else {
        // 아직 공유 중
        setState(() {
          _linked = true;
          _ownerUid = snap.docs.first.id;
        });
      }
    });
  }

  void _onEmotionDataChanged() {
    if (!mounted) return;
    setState(() {
      _mostFrequentEmotion = getMostFrequentEmotion(emotionDataNotifier.value);
    });
  }

  // ---------- 역할/연결 상태 해석 + 일기 스트림 세팅 ----------
  Future<void> _resolveOwnerAndLink() async {
    try {
      final myUid = FirebaseAuth.instance.currentUser!.uid;

      // 1) 내 역할 조회
      final meDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      final me = meDoc.data() ?? {};
      final role = (me['role'] as String?) ?? 'senior';
      String resolvedOwner = myUid;
      bool linked = false;

      if (role == 'guardian') {
        // 보호자: sharedWith == myUid 인 시니어 한 명 찾기
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('sharedWith', isEqualTo: myUid)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          resolvedOwner = q.docs.first.id;
          linked = true;
        } else {
          resolvedOwner = ''; // 연결 없음
          linked = false;
        }
      } else {
        // 시니어: 내 문서의 sharedWith 존재 여부로 linked 판단
        final sw = me['sharedWith'];
        linked = (sw is String && sw.isNotEmpty);
        resolvedOwner = myUid;
      }

      if (!mounted) return;
      setState(() {
        _myRole = role;
        _ownerUid = resolvedOwner;
        _linked = linked;
        _resolving = false;
      });

      // ✅ 가디언일 때만 링크 상태 리스너를 설정 (시니어는 설정 금지)
      if (role == 'guardian') {
        _setupGuardianLinkListener();
      } else {
        // 안전: 혹시 이전 세션 잔여 리스너가 있다면 정리
        await _guardianSub?.cancel();
        _guardianSub = null;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _resolving = false;
      });
    }
  }

  // ---------- 로그아웃 ----------
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    navigateReset(context, const AccountRegisterScreen()); // 원웨이 초기화
  }

  // ---------- 시니어: 공유 끊기 ----------
  Future<void> _unlinkGuardianAsSenior() async {
    if (_myRole != 'senior') return;
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'sharedWith': FieldValue.delete(),
      });
      // UI 갱신
      await _resolveOwnerAndLink();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유가 해제되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('공유 해제 실패: $e')),
      );
    }
  }

  // ---------- 감정 통계용(기존 로직 유지) ----------
  String getMostFrequentEmotion(Map<String, Map<String, String>> data) {
    final count = <String, int>{'기분 좋음': 0, '보통': 0, '기분 안 좋음': 0};
    for (final v in data.values) {
      final e = v['emotion'] ?? '보통';
      if (count.containsKey(e)) count[e] = (count[e] ?? 0) + 1;
    }
    final maxVal = count.values.fold<int>(0, (p, c) => c > p ? c : p);
    final tops = count.entries.where((e) => e.value == maxVal).map((e) => e.key).toList();
    if (tops.length != 1) return '모든 감정이 비슷하게 선택되었어요';
    return tops.first;
  }

  String getEmotionEmoji(String emotion) {
    switch (emotion) {
      case '기분 좋음': return '😊';
      case '보통': return '😐';
      case '기분 안 좋음': return '😞';
      case '모든 감정이 비슷하게 선택되었어요': return '🤷';
      default: return '';
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text('달력'),
      actions: [
        // 링크 상태 뱃지
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              Icon(_linked ? Icons.link : Icons.link_off,
                  color: _linked ? Colors.green : Colors.grey, size: 20),
              const SizedBox(width: 4),
              Text(_linked ? '공유 중' : '공유 안 됨',
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          ),
        ),
        PopupMenuButton<String>(
          offset: const Offset(0, 40),
          onSelected: (v) async {
            if (v == '검색') {
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchDiaryScreen()));
            } else if (v == '통계') {
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EmotionStatsScreen()));
            } else if (v == '공유 등록') {
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyInviteCodeScreen()));
            } else if (v == '코드 입력') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteCodeInputScreen()));
            } else if (v == '공유 끊기') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('공유 끊기'),
                  content: const Text('정말 공유를 끊으시겠어요?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('끊기')),
                  ],
                ),
              );
              if (ok == true) await _unlinkGuardianAsSenior();
            } else if (v == '로그아웃') {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('로그아웃')),
                  ],
                ),
              );
              if (ok == true) await _signOut();
            } else if (v == '계정 삭제') {
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DeleteAccountScreen()));
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: '검색',
                child: Row(children: const [Icon(Icons.search), SizedBox(width: 10), Text('검색')]),
              ),
              PopupMenuItem(
                value: '통계',
                child: Row(children: const [Icon(Icons.bar_chart), SizedBox(width: 10), Text('통계')]),
              ),
            ];
            // ✅ 시니어 & 아직 공유 안 됨 → "공유 등록" 노출
            if (_myRole == 'senior' && !_linked) {
              items.add(const PopupMenuDivider());
              items.add(PopupMenuItem(
                value: '공유 등록',
                child: Row(children: const [Icon(Icons.person_add_alt_1), SizedBox(width: 10), Text('공유 등록')]),
              ));
            }
            // ✅ 보호자 & 아직 연결 안 됨 → "코드 입력"
            if (_myRole == 'guardian' && !_linked) {
              items.add(const PopupMenuDivider());
              items.add(PopupMenuItem(
                value: '코드 입력',
                child: Row(children: const [Icon(Icons.key), SizedBox(width: 10), Text('코드 입력')]),
              ));
            }
            // 시니어 & 공유 중일 때만 "공유 끊기"
            if (_myRole == 'senior' && _linked) {
              items.add(const PopupMenuDivider());
              items.add(PopupMenuItem(
                value: '공유 끊기',
                child: Row(children: const [Icon(Icons.link_off), SizedBox(width: 10), Text('공유 끊기')]),
              ));
            }
            items.add(const PopupMenuDivider());
            items.add(PopupMenuItem(
              value: '로그아웃',
              child: Row(children: const [Icon(Icons.logout), SizedBox(width: 10), Text('로그아웃')]),
            ));
            items.add(const PopupMenuDivider());
            items.add(PopupMenuItem(
              value: '계정 삭제',
              child: Row(children: const [
                Icon(Icons.delete_outline),
                SizedBox(width: 10),
                Text('계정 삭제'),
              ]),
            ));
            return items;
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.menu, color: Colors.black), SizedBox(width: 8),
              Text('메뉴', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ],
    );

    if (_resolving) {
      return Scaffold(appBar: appBar, body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(appBar: appBar, body: Center(child: Text('오류: $_error')));
    }
    if (_ownerUid == null || _ownerUid!.isEmpty) {
      // 보호자인데 아직 연결 안 되어 있을 때(원웨이 정책상 여기서 온보딩으로 돌려보내지 않음)
      return Scaffold(appBar: appBar, body: const Center(child: Text('연결된 시니어가 없습니다.')));
    }

    // ownerUid 확정 → 해당 diaries 스트림 구독
    final diaryStream = FirebaseFirestore.instance
        .collection('users').doc(_ownerUid)
        .collection('diaries')
        .orderBy('date')
        .snapshots();

    return Scaffold(
      appBar: appBar,
      resizeToAvoidBottomInset: false, // 키보드 올라와도 달력 줄어들지 않음 (기존 유지)
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: diaryStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}'));
            }
            if (snapshot.hasData) {
              final newData = <String, Map<String, String>>{};
              for (final d in snapshot.data!.docs) {
                final m = d.data();
                newData[d.id] = {
                  'emotion': m['emotion'] ?? '',
                  'diary': m['note'] ?? '',
                };
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) emotionDataNotifier.value = newData;
              });
            }

            // --- 달력 헤더(예전 느낌: 월 표기 + 좌우 이동) ---
            final monthHeader = Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _goPrevMonth,
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _monthTitle(_focusedDay),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _goNextMonth,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );

            // --- 달력 자체(총 높이: 요일줄 + 6행) ---
            final dpr = MediaQuery
                .of(context)
                .devicePixelRatio;
            double snapDown(double v) => (v * dpr).floor() / dpr;
            final double epsilon = 1 / dpr;

            const double rowH = 60.0;
            const double dowH = 32.0;

            final double calendarTotal = snapDown(dowH + rowH * 6);

            /*final media = MediaQuery.of(context);
            final clamped = media.copyWith(
              textScaler: media.textScaler.clamp(
                  minScaleFactor: 0.9, maxScaleFactor: 1.0),
            );*/

// 실제 달력 위젯
            final calendar = ClipRect(
                child: SizedBox(
                  height: calendarTotal,
                  child: TableCalendar(
                    locale: 'ko_KR',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,

                    headerVisible: false,
                    sixWeekMonthsEnforced: true,
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const { CalendarFormat.month: 'Month' },

                    rowHeight: rowH,
                    daysOfWeekHeight: dowH,

                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(fontSize: 14),
                      weekendStyle: TextStyle(fontSize: 14),
                    ),

                    calendarStyle: const CalendarStyle(
                      disabledTextStyle: TextStyle(color: Colors.grey),
                      cellPadding: EdgeInsets.zero,
                      cellMargin: EdgeInsets.zero,
                      tablePadding: EdgeInsets.zero,
                    ),

                    selectedDayPredicate: (day) =>
                    _selectedDay != null && isSameDay(_selectedDay, day),
                    enabledDayPredicate: (day) => _isSameOrBeforeToday(day),

                    onDaySelected: (selectedDay, focusedDay) async {
                      if (_myRole == 'guardian' && !_linked) {
                        setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                        return;
                      }
                      if (!_isSameOrBeforeToday(selectedDay)) return;

                      setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                      if (_myRole == 'guardian' && _linked) return;

                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EmotionInputScreen(selectedDay: selectedDay)),
                      );
                      if (!mounted) return;
                      setState(() {
                        _focusedDay = selectedDay;
                        _viewingEmotion = null;
                        _viewingDiary = null;
                      });
                    },
                    onPageChanged: (fd) => setState(() => _focusedDay = fd),

                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) =>
                          _buildCalendarCell(context, day, focusedDay, rowH),
                      todayBuilder: (context, day, focusedDay) =>
                          _buildCalendarCell(context, day, focusedDay, rowH, today: true),
                      selectedBuilder: (context, day, focusedDay) =>
                          _buildCalendarCell(context, day, focusedDay, rowH, selected: true),
                    ),
                  ),
                ),
            );

            // --- 다이어리 패널 표시 여부 ---
            final bool showDiary = (_myRole == 'guardian' && _linked);

            // --- 다이어리 패널 ---
            final diaryPanel = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F0FA),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: const <Widget>[
                                Icon(Icons.calendar_today, size: 20),
                                SizedBox(width: 8),
                              ],
                            ),
                            Text(
                              getEmotionEmoji(
                                (_selectedDay != null
                                    ? (emotionDataNotifier.value[formatDate(_selectedDay!)]?['emotion'])
                                    : null) ?? '',
                              ),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedDay != null ? formatDate(_selectedDay!) : '',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          (() {
                            if (_selectedDay == null) return '작성된 일기가 없습니다.';
                            final d = emotionDataNotifier.value[formatDate(_selectedDay!)]?['diary'] ?? '';
                            return d.isNotEmpty ? d : '작성된 일기가 없습니다.';
                          })(),
                          style: const TextStyle(fontSize: 16, height: 1.6),
                          textAlign: TextAlign.start,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      monthHeader,
                      calendar,
                      if (showDiary) Expanded(child: diaryPanel),
                    ],
                  );
                },
              ),
            );
          }

  Widget _buildCalendarCell(
      BuildContext context,
      DateTime day,
      DateTime focusedDay,
      double rowHeight, {
        bool selected = false,
        bool today = false,
      }) {
    // 보호자 미연결+미래일 비활성화 처리
    if (_myRole == 'guardian' && !_linked && !_isBeforeToday(day)) {
      return const SizedBox.shrink();
    }

    final dateStr = formatDate(day);
    final emotion = emotionDataNotifier.value[dateStr]?['emotion'];
    final emoji = getEmotionEmoji(emotion ?? '');
    final isToday = isSameDay(day, DateTime.now());

    // 1) 안전여유(5px) 확보한 shrink
    final double baseRow = rowHeight;
    double shrink = (rowHeight  - 1.0) / baseRow;

    // 2) 폰트/패딩 베이스 (예전 코드와 호환)
    const double baseDayFs   = 14.0;
    const double baseEmojiFs = 18.0;
    const double basePad     = 8.0;  // 선택 칩 내부 패딩
    const double baseGap     = 1.0;  // 칩-이모지 간격
    const double textHFactor = 1.1;  // 텍스트 실제 높이 보정치

    // 3) 이론상 컨텐츠 총높이 추정 → 혹시 모자라면 한 번 더 축소
    final double estDayH   = baseDayFs   * textHFactor * shrink;
    final double estEmojiH = baseEmojiFs * textHFactor * shrink;
    final double estTotal  = (basePad * 2 * shrink) + estDayH + baseGap + estEmojiH;

    if (estTotal > rowHeight) {
      final k = (rowHeight - 1.0) / estTotal;        // 1px 추가 여유
      shrink = (shrink * k).clamp(0.55, shrink);     // 과축소 방지 하한 0.55
    }

    final dayLabel = Text(
      '${day.day}',
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: baseDayFs * shrink,
        fontWeight: (selected || isToday) ? FontWeight.bold : FontWeight.normal,
        color: selected ? Colors.white : null,
        height: 1.0,
      ),
    );

    final dayChip = Container(
      padding: EdgeInsets.all(basePad * shrink),
      decoration: BoxDecoration(
        color: selected ? Colors.blue : null,
        shape: BoxShape.circle,
      ),
      child: dayLabel,
    );

    final emojiLabel = Text(
      emoji.isNotEmpty ? emoji : ' ',
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontSize: baseEmojiFs * shrink,
        height: 1.0,
      ),
    );

    // ✅ 핵심: 내부 여백/간격을 아주 작게(또는 거의 0) 유지하고,
    //    mainAxisSize: min 으로 Column이 필요한 만큼만 차지하게.
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dayChip,
        const SizedBox(height: 1.0), // baseGap 값 그대로
        emojiLabel,
      ],
    );
  }

  Future<void> _loadEmotionData() async {
    final ownerUid = await resolveOwnerUid();
    final data = ownerUid == null
        ? <String, Map<String, String>>{}
        : await loadEmotionDataFromFirestoreFor(ownerUid: ownerUid);

    emotionDataNotifier.value = data;
    _mostFrequentEmotion = getMostFrequentEmotion(data);
  }

  void _loadEmotionDataIfUserExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("❌ 현재 로그인된 유저 없음 (currentUser == null)");
      return;
    }
    print("✅ 현재 로그인된 UID: ${user.uid}");

    final ownerUid = await resolveOwnerUid();
    final data = ownerUid == null
        ? <String, Map<String, String>>{}
        : await loadEmotionDataFromFirestoreFor(ownerUid: ownerUid);

    emotionDataNotifier.value = data;
  }
}
