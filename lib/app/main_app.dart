import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/di/injection_container.dart';
import '../presentation/bloc/download_bloc.dart';
import '../presentation/bloc/download_event.dart';
import '../presentation/screens/downloads_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/reels_screen.dart';

class ReelApp extends StatelessWidget {
  const ReelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reelo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 1; // Start on Reels tab

  // Screens are rebuilt on tab change so isActive reflects the current tab.
  List<Widget> get _screens => [
        const HomeScreen(),
        ReelsScreen(isActive: _selectedIndex == 1),
        const DownloadsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DownloadBloc>(
      // Singleton from DI; load persisted downloads immediately.
      create: (_) => sl<DownloadBloc>()..add(const LoadDownloads()),
      child: Scaffold(
        // IndexedStack keeps all three screens alive to preserve BLoC state
        // and avoid re-fetching videos when switching tabs.
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline),
              activeIcon: Icon(Icons.play_circle),
              label: 'Reels',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.download_outlined),
              activeIcon: Icon(Icons.download),
              label: 'Downloads',
            ),
          ],
        ),
      ),
    );
  }
}
