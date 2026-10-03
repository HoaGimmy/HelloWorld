import 'package:flutter/material.dart';


import 'screens/customers_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/tasks_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pipeline_screen.dart';
import 'widgets/mpwindows_brand.dart';
import 'services/theme_color_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  await ThemeColorController.instance.load();
  runApp(const MPWindowsCRMApp());
}

class MPWindowsCRMApp extends StatelessWidget {
  const MPWindowsCRMApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Color>(
        valueListenable: ThemeColorController.instance,
        builder: (context, seedColor, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MPWindows CRM',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
            inputDecorationTheme: const InputDecorationTheme(isDense: true),
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

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

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
        onDestinationSelected: (v) => setState(() => index = v),
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
