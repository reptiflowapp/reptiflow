import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/rack/rack_screen.dart';
import 'screens/reptiles/reptiles_screen.dart';
import 'screens/work/work_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();
  await Supabase.initialize(
    url: 'https://uutdigtsjwvjechcpkpd.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1dGRpZ3Rzand2amVjaGNwa3BkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5ODIxMjIsImV4cCI6MjA5NDU1ODEyMn0.u2AlZq1FBMsciIicajnF07vxWWna3W6uyIezUcjaI-Y',
  );

  runApp(const RetiflowApp());
}

class RetiflowApp extends StatelessWidget {
  const RetiflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retiflow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4CAF82),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const AuthGate(),
    );
  }
}

// 인증 상태에 따라 로그인 화면 / 홈 화면 분기
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // 스트림 업데이트가 있으면 실제 세션 기준으로 판단
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
          onGoToRacks: () => setState(() => _currentIndex = 1)),
      const RackScreen(),
      const WorkScreen(),
      const CalendarScreen(),
      const ReptilesScreen(),
    ];
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    // 로그아웃 후 AuthGate의 StreamBuilder가 자동으로 LoginScreen으로 전환
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        title: const Text(
          'retiflow',
          style: TextStyle(
            color: Color(0xFF4CAF82),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.grey),
            tooltip: '로그아웃',
            onPressed: _signOut,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: const Color(0xFF4CAF82),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: '렉'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_outline), label: '작업'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: '캘린더'),
          BottomNavigationBarItem(icon: Icon(Icons.pets_outlined), label: '개체'),
        ],
      ),
    );
  }
}
