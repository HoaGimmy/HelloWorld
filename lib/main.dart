import 'package:flutter/material.dart';


import 'screens/customers_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/tasks_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pipeline_screen.dart';
import 'widgets/mpwindows_brand.dart';
import 'services/theme_color_controller.dart';
import 'services/ios_native_service.dart';
import 'services/google_drive_backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  await ThemeColorController.instance.load();
  runApp(const MPWindowsCRMApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    IOSNativeService.instance.initialize();
  });
}

class MPWindowsCRMApp extends StatelessWidget {
  const MPWindowsCRMApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Color>(
        valueListenable: ThemeColorController.instance,
        builder: (context, seedColor, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          ),
          title: 'MPWindows CRM',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
            scaffoldBackgroundColor: const Color(0xFFF7F7F8),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: Color(0xFFF7F7F8),
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                color: Color(0xFF171717),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            cardTheme: const CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            navigationBarTheme: const NavigationBarThemeData(
              height: 68,
              elevation: 0,
              backgroundColor: Colors.white,
              indicatorShape: StadiumBorder(),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            ),
          ),
          initialRoute: '/',
          routes: {
            '/': (_) => const MPWindowsSplashScreen(),
            '/home': (_) => const HomeScreen(),
          },
        ),
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runAutoBackup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runAutoBackup();
  }

  Future<void> _runAutoBackup() async {
    try {
      await GoogleDriveBackupService.instance.autoBackupIfDue();
    } catch (_) {
      // Auto backup must never block opening the CRM. Manual backup shows errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(),
      const CustomersScreen(),
      const PipelineScreen(),
      const TasksScreen(),
      const CalendarScreen(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => index = v);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Khách hàng'),
          NavigationDestination(icon: Icon(Icons.view_kanban_outlined), selectedIcon: Icon(Icons.view_kanban), label: 'Hành trình'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Công việc'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Lịch'),
        ],
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;
  const _SimplePage({required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 54),
                const SizedBox(height: 14),
                Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
}
