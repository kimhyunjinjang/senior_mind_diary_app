import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pie_chart/pie_chart.dart';
import 'dart:math';
import 'package:flutter/services.dart';

class InviteCodeInputScreen extends StatefulWidget {
  @override
  State<InviteCodeInputScreen> createState() => _InviteCodeInputScreenState();
}

class _InviteCodeInputScreenState extends State<InviteCodeInputScreen> {
  final _controller = TextEditingController();
  String? _error;

  Future<void> _verifyCode() async {
    final input = _controller.text.trim();
    final doc = await FirebaseFirestore.instance
        .collection('inviteCodes')
        .doc(input)
        .get();

    if (!doc.exists) {
      setState(() => _error = "존재하지 않는 코드입니다.");
      return;
    }

    final ownerUid = doc.data()?['ownerUid'];
    final viewerUid = FirebaseAuth.instance.currentUser!.uid;

    if (ownerUid == viewerUid) {
      print("⚠️ [테스트] 본인 코드 입력: 연결 허용됨");
      // 테스트이므로 연결은 그대로 진행. 실제 배포 전엔 반드시 차단으로 되돌려야 함!
      // setState(() => _error = "본인의 코드입니다.");
      // return;
    }

    // 보호자로 등록
    await FirebaseFirestore.instance
        .collection('users')
        .doc(ownerUid)
        .set({
      'sharedWith': FieldValue.arrayUnion([viewerUid])
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("연결이 완료되었습니다.")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("인증 코드 입력")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "시니어에게 받은 인증 코드",
                errorText: _error,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _verifyCode,
              child: Text("코드 인증"),
            ),
          ],
        ),
      ),
    );
  }
}

class InviteCodeGenerateScreen extends StatelessWidget {
  const InviteCodeGenerateScreen({super.key});

  // 랜덤 인증 코드 생성
  Future<String> generateAndSaveInviteCode(String ownerUid) async {
    final code = _generateRandomCode(6);
    final docRef = FirebaseFirestore.instance.collection('inviteCodes').doc(code);

    await docRef.set({
      'ownerUid': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("보호자 초대")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final code = await generateAndSaveInviteCode(uid);

            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text("초대 코드"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("이 코드를 보호자에게 전달하세요:"),
                    SizedBox(height: 12),
                    SelectableText(
                      code,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: Icon(Icons.copy),
                      label: Text("복사하기"),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        //Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("복사되었습니다!")),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          child: Text("인증 코드 생성하기"),
        ),
      ),
    );
  }
}

class RoleSelectScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("당신은 누구신가요?")),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InviteCodeGenerateScreen(),
                  ),
                );
              },
              icon: Icon(Icons.edit),
              label: Text("👴 나는 일기를 기록하려는 사용자입니다"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: EdgeInsets.all(16),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InviteCodeInputScreen(),
                  ),
                );
              },
              icon: Icon(Icons.visibility),
              label: Text("👨 나는 가족의 일기를 열람하려는 사용자입니다"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum UserRole { senior, guardian }

class RoleToggle extends StatefulWidget {
  final UserRole currentRole;
  final ValueChanged<UserRole> onRoleChanged;

  const RoleToggle({required this.currentRole, required this.onRoleChanged, super.key});

  @override
  State<RoleToggle> createState() => _RoleToggleState();
}

class _RoleToggleState extends State<RoleToggle> {
  late UserRole _role;

  @override
  void initState() {
    super.initState();
    _role = widget.currentRole;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<UserRole>(
      value: _role,
      items: const [
        DropdownMenuItem(value: UserRole.senior, child: Text("👴 시니어 모드")),
        DropdownMenuItem(value: UserRole.guardian, child: Text("👨 보호자 모드")),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _role = value);
          widget.onRoleChanged(value);
        }
      },
    );
  }
}

Future<Map<String, Map<String, String>>> loadEmotionDataFromFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};

  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('diaries')
      .get();

  Map<String, Map<String, String>> result = {};
  for (var doc in snapshot.docs) {
    final date = doc.id; // 문서 ID가 날짜
    final data = doc.data();
    result[date] = {
      'emotion': data['emotion'] ?? '',
      'diary': data['note'] ?? '',
    };
  }

  return result;
}

class SearchDiaryScreen extends StatefulWidget {
  const SearchDiaryScreen({super.key});

  @override
  State<SearchDiaryScreen> createState() => _SearchDiaryScreenState();
}

class _SearchDiaryScreenState extends State<SearchDiaryScreen> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final diaryData = emotionDataNotifier.value;
    final filteredEntries = diaryData.entries.where((entry) {
      final diaryText = entry.value['diary'] ?? '';
      return _keyword.isEmpty || diaryText.toLowerCase().contains(_keyword.toLowerCase()); // 대소문자 상관 없이 검색하기
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('일기 검색')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: '검색어를 입력하세요',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _keyword = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(child: Text('일치하는 일기가 없습니다.', style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: filteredEntries.length,
              itemBuilder: (context, index) {
                final date = filteredEntries[index].key;
                final emotion = filteredEntries[index].value['emotion'] ?? '';
                final diary = filteredEntries[index].value['diary'] ?? '';

                return ListTile(title: Text('[$date] $emotion'),
                  subtitle: RichText(text: TextSpan(
                    children: _highlightKeyword(diary, _keyword),
                    style: const TextStyle(color: Colors.black), // 기본 스타일
                  ),
                ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightKeyword(String text, String keyword) {
    if (keyword.isEmpty) return [TextSpan(text: text)];

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();

    int start = 0;
    int index;

    while ((index = lowerText.indexOf(lowerKeyword, start)) != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + keyword.length),
        style: const TextStyle(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = index + keyword.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }
}

ValueNotifier<Map<String, Map<String, String>>> emotionDataNotifier = ValueNotifier({});

class EmotionStatsScreen extends StatelessWidget {
  const EmotionStatsScreen({super.key});

  Future<Map<String, double>> _getEmotionCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('emotionData');
    Map<String, Map<String, String>> data = {};

    if (jsonString != null) {
      final raw = json.decode(jsonString);
      data = Map<String, Map<String, String>>.from(
        raw.map((k, v) => MapEntry(k, Map<String, String>.from(v))),
      );
    }

    // 초기화
    Map<String, double> counts = {
      '😊 기분 좋음': 0,
      '😐 보통': 0,
      '😞 기분 안 좋음': 0,
    };

    // 데이터 집계
    for (var value in data.values) {
      final emotion = value['emotion'];
      switch (emotion) {
        case '기분 좋음':
          counts['😊 기분 좋음'] = counts['😊 기분 좋음']! + 1;
          break;
        case '보통':
          counts['😐 보통'] = counts['😐 보통']! + 1;
          break;
        case '기분 안 좋음':
          counts['😞 기분 안 좋음'] = counts['😞 기분 안 좋음']! + 1;
          break;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('감정 통계'),
      ),
      body: FutureBuilder<Map<String, double>>(
        future: _getEmotionCounts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final dataMap = snapshot.data!;
          final total = dataMap.values.reduce((a, b) => a + b);
          final showChart = total > 0;

          return Center(
            child: showChart
                ? PieChart(
              dataMap: dataMap,
              animationDuration: Duration(milliseconds: 800),
              chartRadius: MediaQuery.of(context).size.width / 1.5,
              chartType: ChartType.disc,
              legendOptions: LegendOptions(
                showLegends: true,
                legendPosition: LegendPosition.bottom,
                legendTextStyle: TextStyle(fontSize: 16),
              ),
              chartValuesOptions: ChartValuesOptions(
                showChartValuesInPercentage: true,
                showChartValues: true,
                decimalPlaces: 0,
              ),
            )
                : Text(
              '아직 감정 기록이 없어요 😢',
              style: TextStyle(fontSize: 18),
            ),
          );
        },
      ),
    );
  }
}

// 날짜를 yyyy-MM-dd 형식으로 포맷하는 함수
String formatDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 초기화
  await initializeDateFormatting('ko_KR', null); // 한글 날짜 포맷 초기화
  // Firebase 초기화
  await Firebase.initializeApp(
    options: CustomFirebaseOptions.currentPlatform,
  );
  // 익명 로그인 시도
  await _signInAnonymously();
  runApp(const MyApp());
}

Future<void> _signInAnonymously() async {
  try {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    final user = userCredential.user;
    if (user != null) {
      print('익명 로그인 성공: ${user.uid}');
    }
  } catch (e) {
    print('익명 로그인 실패: $e');
  }
}

Future<void> saveEmotionAndNote({
  required String date,       // 예: '2025-05-02'
  required String emotion,    // 예: 'happy', 'neutral', 'sad'
  required String note,       // 예: '산책을 해서 기분이 좋았어요'
}) async {
  print('📌 saveEmotionAndNote 시작됨');

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('로그인된 사용자가 없습니다.');
    return;
  }

  final uid = user.uid;
  print('🧑 현재 UID: $uid');

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('diaries')
        .doc(date)
        .set({
      'emotion': emotion,
      'note': note,
      'timestamp': FieldValue.serverTimestamp(),
    });

    print('Firestore 저장 성공');
  } catch (e) {
    print('Firestore 저장 실패: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      //home: const MyHomePage(title: 'Flutter Demo Home Page'),
      home: CalendarScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String _mostFrequentEmotion = '보통';

  @override
  void initState(){
    super.initState();
    _loadEmotionData(); // 앱 실행 시 감정 데이터 불러오기
    _debugPrintAppDir(); // 콘솔에 경로 출력

    emotionDataNotifier.addListener((){
      print('감정 데이터 변경됨: ${emotionDataNotifier.value}');
      setState(() {
        _mostFrequentEmotion = getMostFrequentEmotion(emotionDataNotifier.value);
      });
    });
  }

  Future<void> _loadEmotionData() async {
    /*final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('emotionData');
    print('불러온 JSON 문자열: $jsonString');

    if (jsonString != null) {
      final raw = json.decode(jsonString);
      final data = Map<String, Map<String, String>>.from(
          raw.map((k, v) => MapEntry(k, Map<String, String>.from(v)))
      );
      emotionDataNotifier.value = data;
      _mostFrequentEmotion = getMostFrequentEmotion(data);
    }*/
    final data = await loadEmotionDataFromFirestore();
    emotionDataNotifier.value = data;
    _mostFrequentEmotion = getMostFrequentEmotion(data);
  }

  void _debugPrintAppDir() async {
    final dir = await getApplicationSupportDirectory();
    print('🗂️ 앱 저장 경로: ${dir.path}');
  }

  String getMostFrequentEmotion(Map<String, Map<String, String>> data) {
    Map<String, int> count = {
      '기분 좋음' : 0,
      '보통' : 0,
      '기분 안 좋음' : 0,
    };

    for (var value in data.values) {
      final emotion = value['emotion'] ?? '보통';
      if (count.containsKey(emotion)) {
        count[emotion] = count[emotion]! + 1;
      }
    }

    // 최대 빈도 찾기
    int maxCount = count.values.fold(0, (prev, curr) => curr > prev ? curr : prev);
    final maxEmotions = count.entries.where((e) => e.value == maxCount).map((e) => e.key).toList();

    // 동점일 경우 '보통'으로
    if (maxEmotions.length != 1) return '모든 감정이 비슷하게 선택되었어요';

    return maxEmotions.first;
  }

  String getEmotionEmoji(String emotion) {
    switch (emotion) {
      case '기분 좋음':
        return '😊';
      case '보통':
        return '😐';
      case '기분 안 좋음':
        return '😞';
      case '모든 감정이 비슷하게 선택되었어요':
        return '🤷';
      default:
        return '';
    }
  }

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  UserRole _currentRole = UserRole.senior;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('시니어 마음일기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchDiaryScreen(),),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.pie_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EmotionStatsScreen(),),
              );
            },
          ),
          RoleToggle(
            currentRole: _currentRole,
            onRoleChanged: (newRole) {
              setState(() {
                _currentRole = newRole;
                print(' 현재 역할: $_currentRole');
              });
            },
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RoleSelectScreen(),
              ),
            );
          },
          child: Text("보호자 등록"),
        ),
        ],
      ),
      body: Column(
        children: [
          // 감정 최빈값 상단 표시
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
              Text(
              '가장 자주 느낀 감정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
              Text(
                getEmotionEmoji(_mostFrequentEmotion),
                style: const TextStyle(fontSize: 36),
              ),
              ],
            ),
          ),

      // 캘린더
      ValueListenableBuilder(
            valueListenable: emotionDataNotifier,
            builder: (context, emotionMap, _){
              return TableCalendar(
                locale: 'ko_KR',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,

                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                enabledDayPredicate: (day) => !day.isAfter(DateTime.now()),
                calendarStyle: CalendarStyle(
                  disabledTextStyle: TextStyle(color: Colors.grey), // 미래는 회색
                ),
                onDaySelected: (selectedDay, focusedDay) async {
                  if (selectedDay.isAfter(DateTime.now())) return; // 미래면 클릭 무시

                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });

                  // 감정 입력 화면 다녀오기
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmotionInputScreen(selectedDay: selectedDay),
                    ),
                  );

                  // 데이터 다시 불러오기
                  await _loadEmotionData();

                  // 강제로 selectedDay를 한번 무효화했다가 다시 설정
                  setState(() {
                    _selectedDay = null;
                  });

                  Future.delayed(Duration(milliseconds: 50), () {
                    setState(() {
                      _focusedDay = selectedDay; // 다시 원래 날짜로 복귀해서 리렌더 유도
                    });
                  });
                },

                // 감정 이모티콘 셀
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final dateStr = formatDate(day);
                    final emotion = emotionDataNotifier.value[dateStr]?['emotion'];
                    String emoji = '';

                    if (emotion != null) {
                      if (emotion == '기분 좋음')
                        emoji = '😊';
                      else if (emotion == '보통')
                        emoji = '😐';
                      else
                        emoji = '😞';
                    }

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text('${day.day}',
                              style: TextStyle(fontWeight: isSameDay(day, DateTime.now()) ? FontWeight.bold : FontWeight.normal)),
                          if (emoji.isNotEmpty) Text(emoji),
                        ],
                      );
                    },

                  todayBuilder: (context, day, focusedDay) {
                    final dateStr = formatDate(day);
                    final emotion = emotionDataNotifier.value[dateStr]?['emotion'];
                    String emoji = '';

                    if (emotion != null) {
                      if (emotion == '기분 좋음') emoji = '😊';
                      else if (emotion == '보통') emoji = '😐';
                      else emoji = '😞';
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text('${day.day}', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (emoji.isNotEmpty) Text(emoji),
                      ],
                    );
                  },
                ),
              );
            },
          )
        ],
      ),
    );
  }
}

class EmotionInputScreen extends StatefulWidget {
  final DateTime selectedDay;

  const EmotionInputScreen({super.key, required this.selectedDay});

  @override
  State<EmotionInputScreen> createState() => _EmotionInputScreenState();
}

class _EmotionInputScreenState extends State<EmotionInputScreen> {
  final TextEditingController _diaryController = TextEditingController();
  String? _selectedEmotion;

  @override
  void initState() {
    super.initState();
    _loadSavedDiary(); // 일기 내용 불러오기
  }

  Future<void> _loadSavedDiary() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('emotionData');
    if (jsonString != null) {
      final raw = json.decode(jsonString);
      final data = Map<String, Map<String, String>>.from(
        raw.map((k, v) => MapEntry(k, Map<String, String>.from(v))),
      );
      final formattedDate = formatDate(widget.selectedDay);
      final saved = data[formattedDate];
      if (saved != null) {
        setState(() {
          _selectedEmotion = saved['emotion'];
          _diaryController.text = saved['diary'] ?? '';
        });
      }
    }
  }

  void _saveData() async {
    if (_selectedEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('감정을 선택해주세요.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('emotionData');
    Map<String, dynamic> data = {};
    if (jsonString != null) {
      data = Map<String, dynamic>.from(json.decode(jsonString));
    }

    final formattedDate = formatDate(widget.selectedDay);
    data[formattedDate] = {
      'emotion': _selectedEmotion!,
      'diary': _diaryController.text,
    };

    await prefs.setString('emotionData', json.encode(data));
    emotionDataNotifier.value = Map<String, Map<String, String>>.from(
        data.map((k, v) => MapEntry(k, Map<String, String>.from(v)))
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('감정과 일기가 저장되었습니다.')),
    );

    // Firestore 저장
    await saveEmotionAndNote(
      date: formattedDate,
      emotion: _selectedEmotion!,
      note: _diaryController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('감정과 일기가 저장되었습니다.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.selectedDay.month}월 ${widget.selectedDay.day}일 감정 입력'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('오늘 기분은 어땠나요?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            EmotionButton(
              emoji: '😊', label: '기분 좋음', color: Colors.green.shade300,
              onTap: () => setState(() => _selectedEmotion = '기분 좋음'),
              selected: _selectedEmotion == '기분 좋음',
            ),
            const SizedBox(height: 12),
            EmotionButton(
              emoji: '😐', label: '보통', color: Colors.grey.shade400,
              onTap: () => setState(() => _selectedEmotion = '보통'),
              selected: _selectedEmotion == '보통',
            ),
            const SizedBox(height: 12),
            EmotionButton(
              emoji: '😞', label: '기분 안 좋음', color: Colors.red.shade200,
              onTap: () => setState(() => _selectedEmotion = '기분 안 좋음'),
              selected: _selectedEmotion == '기분 안 좋음',
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _diaryController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '오늘 하루를 간단히 기록해보세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveData,
              child: Text('저장하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? Colors.black54 : color,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}