import 'package:flutter/material.dart';

void main() => runApp(const MPWindowsCRMApp());

class MPWindowsCRMApp extends StatelessWidget {
  const MPWindowsCRMApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MPWindows CRM',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0))),
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  static const pages = <Widget>[_Dashboard(), _Customers(), _Pipeline(), _Tasks(), _Calendar()];
  @override
  Widget build(BuildContext context) => Scaffold(
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

class _Dashboard extends StatelessWidget { const _Dashboard(); @override Widget build(BuildContext c) => const _Page('Tổng quan', Icons.dashboard, 'MPWindows CRM'); }
class _Customers extends StatelessWidget { const _Customers(); @override Widget build(BuildContext c) => const _Page('Khách hàng', Icons.people, 'Quản lý khách hàng'); }
class _Pipeline extends StatelessWidget { const _Pipeline(); @override Widget build(BuildContext c) => const _Page('Hành trình', Icons.view_kanban, 'Pipeline khách hàng'); }
class _Tasks extends StatelessWidget { const _Tasks(); @override Widget build(BuildContext c) => const _Page('Công việc', Icons.checklist, 'Công việc và deadline'); }
class _Calendar extends StatelessWidget { const _Calendar(); @override Widget build(BuildContext c) => const _Page('Lịch hẹn', Icons.event, 'Lịch hẹn khách hàng'); }

class _Page extends StatelessWidget {
  final String title; final IconData icon; final String message;
  const _Page(this.title, this.icon, this.message);
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 52), const SizedBox(height: 16), Text(message, style: Theme.of(context).textTheme.titleLarge)])))),
  );
}
