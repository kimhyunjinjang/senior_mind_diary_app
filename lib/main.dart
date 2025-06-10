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
import 'package:senior_mind_diary_app/globals.dart' as globals;

class AccountRegisterScreen extends StatefulWidget {
  const AccountRegisterScreen({Key? key}) : super(key: key);

  @override
  State<AccountRegisterScreen> createState() => _AccountRegisterScreenState();
}

class _AccountRegisterScreenState extends State<AccountRegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool _isLoading = false;

  Future<void> _register() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    if (_formKey.currentState?.validate() ?? false) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _confirmPasswordError = '비밀번호가 일치하지 않습니다';
        });
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final credential = EmailAuthProvider.credential(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = FirebaseAuth.instance.currentUser;

        if (user != null && user.isAnonymous) {
          // 익명 계정 → 이메일 계정으로 연결 (UID 유지)
          await user.linkWithCredential(credential);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('이미 계정이 등록되어 있습니다.')),
          );
          return;
        }
        // 등록 성공 시 메인 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CalendarScreen()),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          if (e.code == 'email-already-in-use') {
            _emailError = '이미 사용 중인 이메일입니다';
          } else if (e.code == 'weak-password') {
            _passwordError = '비밀번호는 6자 이상 입력하세요';
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message ?? '등록에 실패했습니다')),
            );
          }
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 등록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '계정을 등록하면 앱을 지우거나 휴대폰을 바꿔도 '
                    '일기를 다시 찾을 수 있습니다.\n\n'
                    '비밀번호는 이메일 비밀번호가 아닌 '
                    '이 앱을 사용할 때 사용할 비밀번호입니다.',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  border: const OutlineInputBorder(),
                  errorText: _emailError,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                value != null && value.contains('@') ? null : '올바른 이메일을 입력하세요',
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: const OutlineInputBorder(),
                  errorText: _passwordError,
                ),
                obscureText: false, // 항상 보이게!
                validator: (value) =>
                value != null && value.length >= 6 ? null : '비밀번호는 6자 이상 입력하세요',
              ),
              const SizedBox(height: 8),
              const Text(
                '비밀번호는 6자 이상 입력하세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: '비밀번호 확인',
                  border: const OutlineInputBorder(),
                  errorText: _confirmPasswordError,
                ),
                obscureText: false, // 항상 보이게!
                validator: (value) =>
                value != null && value.isNotEmpty ? null : '비밀번호 확인을 입력하세요',
              ),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '등록',
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // 로그인 화면으로 이동
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: const Text(
                  '계정이 있으신가요? 로그인하기',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 임시 로그인 화면
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          '로그인 화면',
          style: TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}

bool isSameOrBeforeToday(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day); // 오늘 날짜 (00:00:00)

  final localDay = day.toLocal();
  final justDay = DateTime(localDay.year, localDay.month, localDay.day); // 선택한 날짜 (00:00:00)

  return !justDay.isAfter(today);
}

Future<void> loadGuardianModeInfo() async {
  final prefs = await SharedPreferences.getInstance();
  globals.isGuardianMode = prefs.getBool('isGuardianMode') ?? false;
  globals.linkedUserId = prefs.getString('linkedUserId');
}

Future<void> saveGuardianModeInfo(String seniorUID) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isGuardianMode', true);
  await prefs.setString('linkedUserId', seniorUID);

  // 전역 변수도 함께 업데이트
  globals.isGuardianMode = true;
  globals.linkedUserId = seniorUID;
}

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
       setState(() => _error = "본인의 코드입니다.");
       return;
    }

    print('viewerUid: $viewerUid');

    try {
      // 보호자로 등록
      await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .set({
        'sharedWith': FieldValue.arrayUnion([viewerUid])
      }, SetOptions(merge: true));

      // 로컬에 보호자 모드 정보 저장
      await saveGuardianModeInfo(ownerUid);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("연결이 완료되었습니다.")),
      );

      Navigator.pop(context);
    } catch (e, stacktrace) {
      print('🔥 Firestore 쓰기 에러: $e');
      print('🔥 Stacktrace: $stacktrace');
      setState(() => _error = "연결 중 문제가 발생했습니다.");
    }
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
              icon: Icon(Icons.edit, size: 28),
              label: Text("👴 나는 일기를 기록하려는 사용자입니다",
              style: TextStyle(fontSize: 20),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFFF9C4),
                foregroundColor: Colors.black,
                padding: EdgeInsets.all(20),
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
              icon: Icon(Icons.visibility, size: 28),
              label: Text("👨 나는 가족의 일기를 열람하려는 사용자입니다",
              style: TextStyle(fontSize: 20),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFB2EBF2),
                foregroundColor: Colors.black,
                padding: EdgeInsets.all(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum UserRole { senior, guardian }

Future<Map<String, Map<String, String>>> loadEmotionDataFromFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};

  String targetUid;

  if (globals.isGuardianMode) {
    // 보호자 모드: sharedWith 배열에서 시니어 UID 찾기
    final seniorSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('sharedWith', arrayContains: user.uid)
        .get();

    if (seniorSnapshot.docs.isEmpty) {
      return {};  // 보호자와 연결된 시니어 없음
    }
    targetUid = seniorSnapshot.docs.first.id;
  } else {
    // 보호자가 아니면 → 일기 쓸 수 있는 사람 → 시니어처럼 간주
    targetUid = user.uid;
  }

  // targetUid에 해당하는 일기 데이터 가져오기
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(targetUid)
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
    else {
      // SharedPreferences에 없으면, Firestore에서 가져오기
      data = await loadEmotionDataFromFirestore();
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
  // 보호자 모드 정보 로딩
  await loadGuardianModeInfo();
  runApp(const MyApp());
}

Future<void> _signInAnonymously() async {
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    final user = userCredential.user;
}

Future<void> saveEmotionAndNote({
  required String date,       // 예: '2025-05-02'
  required String emotion,    // 예: 'happy', 'neutral', 'sad'
  required String note,       // 예: '산책을 해서 기분이 좋았어요'
}) async {

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return;
  }

  final uid = user.uid;
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
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.grey.shade100, // 드롭다운 배경 색
          textStyle: TextStyle(color: Colors.black, fontSize: 16), // 드롭다운 글자
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          brightness: Brightness.light,
        ),
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

  String? _viewingEmotion;
  String? _viewingDiary;

  @override
  void initState(){
    super.initState();
    _loadEmotionData(); // 앱 실행 시 감정 데이터 불러오기
    _debugPrintAppDir(); // 콘솔에 경로 출력

    _selectedDay = DateTime.now();

    emotionDataNotifier.addListener((){
      setState(() {
        _mostFrequentEmotion = getMostFrequentEmotion(emotionDataNotifier.value);
      });
    });
  }

  Future<void> _loadEmotionData() async {
    final data = await loadEmotionDataFromFirestore();
    emotionDataNotifier.value = data;
    _mostFrequentEmotion = getMostFrequentEmotion(data);
  }

  void _debugPrintAppDir() async {
    final dir = await getApplicationSupportDirectory();
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
        title: const SizedBox.shrink(),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              offset: Offset(0, 40),
              onSelected: (value) {
                if (value == '검색') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => SearchDiaryScreen(),
                  ));
                } else if (value == '통계') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => EmotionStatsScreen(),
                  ));
                } else if (value == '보호자 등록') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => RoleSelectScreen(),
                  ));
                } else if (value == '계정 등록') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => AccountRegisterScreen(),
                  ));
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: '검색',
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.black),
                      SizedBox(width: 10),
                      Text('검색'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: '통계',
                  child: Row(
                    children: [
                      Icon(Icons.bar_chart, color: Colors.black),
                      SizedBox(width: 10),
                      Text('통계'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: '보호자 등록',
                  child: Row(
                    children: [
                      Icon(Icons.family_restroom, color: Colors.black),
                      SizedBox(width: 10),
                      Text('보호자 등록'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: '계정 등록',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.black),
                      SizedBox(width: 10),
                      Text('계정 등록'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      '메뉴',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 감정 최빈값 상단 표시
          /*Padding(
            padding: const EdgeInsets.only(top: 16),
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
          ),*/

      // 캘린더
      ValueListenableBuilder(
            valueListenable: emotionDataNotifier,
            builder: (context, emotionMap, _){
              return TableCalendar(
                locale: 'ko_KR',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,

                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },

                selectedDayPredicate: (day) {
                  if (_selectedDay == null) return false;
                  return isSameDay(_selectedDay, day);
                },
                enabledDayPredicate: (day) => isSameOrBeforeToday(day),

                rowHeight: 60,
                daysOfWeekHeight: 32,
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 14),
                  weekendStyle: TextStyle(fontSize: 14),
                ),

                calendarStyle: CalendarStyle(
                  disabledTextStyle: TextStyle(color: Colors.grey), // 미래는 회색
                ),
                onDaySelected: (selectedDay, focusedDay) async {
                  if (!isSameOrBeforeToday(selectedDay)) {
                    return;
                  }

                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;

                    if (globals.isGuardianMode) {
                      final dateStr = formatDate(selectedDay);
                      final data = emotionDataNotifier.value[dateStr];
                      _viewingEmotion = data?['emotion'];
                      _viewingDiary = data?['diary'];
                    }
                  });

                  if (!globals.isGuardianMode) {
                    // 감정 입력 화면 다녀오기
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EmotionInputScreen(selectedDay: selectedDay),
                      ),
                    );

                    // 데이터 다시 불러오기
                    await _loadEmotionData();

                    Future.delayed(Duration(milliseconds: 50), () {
                      setState(() {
                        _focusedDay = selectedDay; // 다시 원래 날짜로 복귀해서 리렌더 유도
                      });
                    });
                  }
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

                    // shrinkFactor 계산
                    const baseRowHeight = 60.0;
                    final shrinkFactor = 55.0 / baseRowHeight;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(8 * shrinkFactor),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                          child: Text('${day.day}',
                              style: TextStyle(fontWeight: isSameDay(day, DateTime.now())
                                  ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14.0 * shrinkFactor,),),),
                          Padding(
                            padding: const EdgeInsets.only(top: 1.0),
                            child: Text(
                              emoji.isNotEmpty ? emoji : ' ',
                              style: TextStyle(fontSize: 18.0 * shrinkFactor),
                            ),
                          ),
                        ],
                      );
                    },

                  todayBuilder: (context, day, focusedDay) {
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

                    const baseRowHeight = 60.0;
                    final shrinkFactor = 55.0 / baseRowHeight;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.0 * shrinkFactor),
                          decoration: BoxDecoration(shape: BoxShape.circle),
                          child: Text('${day.day}',
                              style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 14.0 * shrinkFactor,)),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 1.0),
                          child: Text(emoji.isNotEmpty ? emoji : ' ',
                              style: TextStyle(fontSize: 18.0 * shrinkFactor),
                          ),
                        ),
                      ],
                    );
                  },

                  selectedBuilder: (context, day, focusedDay) {
                    final dateStr = formatDate(day);
                    final emotion = emotionDataNotifier.value[dateStr]?['emotion'];
                    String emoji = '';

                    if (emotion != null) {
                      if (emotion == '기분 좋음') emoji = '😊';
                      else if (emotion == '보통') emoji = '😐';
                      else emoji = '😞';
                    }

                    const baseRowHeight = 60.0;
                    final shrinkFactor = 55.0 / baseRowHeight;

                    bool isToday = isSameDay(day, DateTime.now());

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding : EdgeInsets.all(8.0 * shrinkFactor),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Text('${day.day}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14.0 * shrinkFactor,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 1.0),
                          child: Text(emoji.isNotEmpty ? emoji : ' ',
                            style: TextStyle(fontSize: 18.0 * shrinkFactor),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),

          if (globals.isGuardianMode && _viewingEmotion != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFFF4F0FA),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // 왼쪽 정렬
                    children: [
                      // 날짜 + 감정 Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                formatDate(_selectedDay!),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            //_viewingEmotion ?? '',
                            getEmotionEmoji(_viewingEmotion ?? ''),
                            style: TextStyle(fontSize: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 일기 본문
                      Text(
                        _viewingDiary ?? '작성된 일기가 없습니다.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.8,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                EmotionButton(
                  emoji: '😊', label: '기분 좋음', color: Colors.lightBlue.shade200,
                  onTap: () => setState(() => _selectedEmotion = '기분 좋음'),
                  selected: _selectedEmotion == '기분 좋음',
                ),
                EmotionButton(
                  emoji: '😐', label: '보통', color: const Color(0xFFE6D3B3),
                  onTap: () => setState(() => _selectedEmotion = '보통'),
                  selected: _selectedEmotion == '보통',
                ),
                EmotionButton(
                  emoji: '😞', label: '기분 안 좋음', color: Colors.grey.shade400,
                  onTap: () => setState(() => _selectedEmotion = '기분 안 좋음'),
                  selected: _selectedEmotion == '기분 안 좋음',
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _diaryController,
              maxLines: 10,
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
                backgroundColor: Colors.indigo.shade400,
                foregroundColor: Colors.white,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 1.0)
              : color.withValues(alpha: 0.6),
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