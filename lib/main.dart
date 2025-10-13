import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:senior_mind_diary_app/globals.dart' as globals;
import 'package:senior_mind_diary_app/utils.dart';

import 'state/app_state.dart';
import 'screens/calendar_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/invite_code_input_screen.dart';
import 'screens/account_register_screen.dart';
import 'state/auth_gate.dart';


class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String _message = '';
  bool _isLoading = false;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _message = '올바른 이메일을 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _message = '비밀번호 재설정 이메일이 전송되었습니다.\n이메일을 확인해주세요.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _message = '해당 이메일로 등록된 계정을 찾을 수 없습니다.';
        } else {
          _message = '이메일 전송에 실패했습니다. 다시 시도해주세요.';
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 찾기')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '등록된 이메일을 입력하시면 비밀번호 재설정 메일을 보내드립니다.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            if (_message.isNotEmpty)
              Text(
                _message,
                style: const TextStyle(color: Colors.blue, fontSize: 14),
              ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _sendResetEmail,
              child: const Text('보내기'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('로그인 화면으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';

  Future<void> signIn() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 로그인 성공 → 메인화면 이동
      navigateReset(context, const AuthGate());
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          errorMessage = '등록되지 않은 이메일입니다.';
        } else if (e.code == 'wrong-password') {
          errorMessage = '비밀번호가 틀렸습니다.';
        } else {
          errorMessage = '로그인에 실패했습니다. 다시 시도해주세요.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('로그인')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      const Text(
                        '이전에 등록한 계정으로 로그인해주세요.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: '이메일',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: false,
                        decoration: const InputDecoration(
                          labelText: '비밀번호',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            '비밀번호를 잊으셨나요?',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      if (errorMessage.isNotEmpty)
                        Text(errorMessage, style: const TextStyle(
                            color: Colors.red)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: signIn,
                        child: const Text('로그인'),
                      ),
                      const SizedBox(height: 1),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (
                                    context) => const AccountRegisterScreen(),
                              ),
                            );
                          },
                          child: const Text('계정이 없으신가요? 등록하기'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
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
  globals.isLinkedNotifier.value = true;
}

class InviteCodeGenerateScreen extends StatelessWidget {
  const InviteCodeGenerateScreen({super.key});

  // 랜덤 인증 코드 생성
  Future<String> generateAndSaveInviteCode(String ownerUid) async {
    final code = _generateRandomCode(6);
    final now = Timestamp.now();
    final expiresAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(hours: 24)),
    );

    await FirebaseFirestore.instance
        .collection('inviteCodes')
        .doc(code)
        .set({
      'ownerUid': ownerUid,
      'createdAt': now,
      'expiresAt': expiresAt,   // 24시간 유효
      'used': false,            // 1회용 플래그
    });

    return code;
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List
        .generate(length, (_) => chars[rand.nextInt(chars.length)])
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("공유 등록")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final code = await generateAndSaveInviteCode(uid);

            showDialog(
              context: context,
              builder: (_) =>
                  AlertDialog(
                    title: Text("초대 코드"),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("이 코드를 보호자에게 전달하세요:"),
                        SizedBox(height: 12),
                        SelectableText(
                          code,
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
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

enum UserRole { senior, guardian }

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
      return _keyword.isEmpty || diaryText.toLowerCase().contains(
          _keyword.toLowerCase()); // 대소문자 상관 없이 검색하기
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
                ? Center(child: Text('일치하는 일기가 없습니다.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
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


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 초기화

  // 세로 모드만 허용
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await initializeDateFormatting('ko_KR', null); // 한글 날짜 포맷 초기화
  // Firebase 초기화
  await Firebase.initializeApp(
    options: CustomFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Senior Mind Diary',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // ✅ 전역 텍스트 테마 추가
        textTheme: const TextTheme(
          // 기본 body 텍스트
          bodyLarge: TextStyle(fontSize: 20, height: 1.6),
          bodyMedium: TextStyle(fontSize: 18, height: 1.6),
          bodySmall: TextStyle(fontSize: 16, height: 1.5),

          // 제목 텍스트
          titleLarge: TextStyle(fontSize: 26, height: 1.5, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 22, height: 1.5, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontSize: 20, height: 1.5, fontWeight: FontWeight.w600),

          // 라벨 텍스트
          labelLarge: TextStyle(fontSize: 18, height: 1.5),
          labelMedium: TextStyle(fontSize: 16, height: 1.5),
          labelSmall: TextStyle(fontSize: 14, height: 1.4),
        ),

        // ✅ 버튼 텍스트 크기
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(fontSize: 20, height: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontSize: 18, height: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),

        // ✅ 입력 필드 텍스트 크기
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(fontSize: 18, height: 1.5),
          hintStyle: TextStyle(fontSize: 18, height: 1.5),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),

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
      // 진입은 이 라우터 한 곳에서만 분기
      home: const AuthGate(),
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
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
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
              style: Theme
                  .of(context)
                  .textTheme
                  .headlineMedium,
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

class EntryRouter extends StatelessWidget {
  const EntryRouter({super.key});

  bool _linked(dynamic sw) => sw is String ? sw.isNotEmpty : (sw is List && sw.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (!auth.hasData) return const AccountRegisterScreen(); // 계정 등록 시작

        final uid = auth.data!.uid;
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final data = snap.data?.data() ?? {};
            final role = data['role'] as String?;
            final done = data['onboardingDone'] == true;

            if (done) return const CalendarScreen();          // 온보딩 완료 → 메인
            if (role == null) return const RoleSelectScreen(); // 역할 미선택 → 역할
            if (role == 'guardian' && !_linked(data['sharedWith'])) {
              return const InviteCodeInputScreen();            // 보호자 미연결 → 코드 입력
            }
            // (시니어인데 done가 false면 다음 화면에서 완료처리됨)
            return const RoleSelectScreen();
          },
        );
      },
    );
  }
}

Future<void> startOnboardingFlow(BuildContext context) async {
  final u = FirebaseAuth.instance.currentUser!;
  await u.reload();                    // 1. 토큰 리프레시
  await u.getIdToken(true);

  await FirebaseFirestore.instance     // 2. 기본 문서 보정
      .collection('users')
      .doc(u.uid)
      .set({
    'createdAt': FieldValue.serverTimestamp(),
    'onboardingDone': false,
  }, SetOptions(merge: true));

  navigateReset(context, const RoleSelectScreen()); // 3. 역할 선택으로 강제 이동
}

// 보호자라면 나를 sharedWith로 갖는 senior 문서를 찾아 seniorUid 반환
Future<String?> _getMySeniorUidIfGuardian(String myUid) async {
  try {
    final q = await FirebaseFirestore.instance
        .collection('users')
        .where('sharedWith', isEqualTo: myUid)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  } on FirebaseException catch (e) {
    debugPrint('🔥 _getMySeniorUidIfGuardian Firestore error: ${e.code} ${e.message}');
    // permission-denied면 일단 보호자 아님으로 취급
    return null;
  } catch (e, st) {
    debugPrint('🔥 unexpected in _getMySeniorUidIfGuardian: $e\n$st');
    return null;
  }
}

Future<void> ensureUserDocumentExists() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
  final snapshot = await docRef.get();

  if (!snapshot.exists) {
    await docRef.set({
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('✅ Firestore에 사용자 문서 생성됨: $uid');
  } else {
    print('🔎 사용자 문서 이미 존재함: $uid');
  }
}

Future<bool> _checkIfGuardian(String currentUid) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('sharedWith', isEqualTo: currentUid)
      .limit(1)
      .get();

  return snapshot.docs.isNotEmpty;
}

Future<void> _signInAnonymously() async {
  final userCredential = await FirebaseAuth.instance.signInAnonymously();
  final user = userCredential.user;
}