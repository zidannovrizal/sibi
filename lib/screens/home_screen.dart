import 'package:flutter/material.dart';

import 'package:google_nav_bar/google_nav_bar.dart';

import '../theme/app_colors.dart';
import 'tabs/home_tab.dart';
import 'tabs/vocabulary_tab.dart';
import 'tabs/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex; // 0: Home, 1: Kosakata, 2: Pengaturan

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: surface,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeTab(
            onNavigate: (idx) => setState(() => _currentIndex = idx),
          ),
          const VocabularyTab(),
          const SettingsTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(surface),
    );
  }

  Widget _buildBottomNavBar(Color surface) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: GNav(
        gap: 8,
        selectedIndex: _currentIndex,
        onTabChange: (index) => setState(() => _currentIndex = index),
        color: Colors.grey.shade600,
        activeColor: Colors.white,
        tabBackgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        tabBorderRadius: 18,
        iconSize: 22,
        textStyle: const TextStyle(
          fontFamily: AppColors.poppins,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        tabs: const [
          GButton(
            icon: Icons.home_filled,
            text: 'Beranda',
          ),
          GButton(
            icon: Icons.menu_book_rounded,
            text: 'Kosakata',
          ),
          GButton(
            icon: Icons.settings_rounded,
            text: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
