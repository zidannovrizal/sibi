import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      title: 'Tangan Nusantara',
      body: 'Belajar bahasa isyarat SIBI dengan pengalaman yang ramah anak.',
      image: 'assets/images/mascot-only.jpg',
    ),
    _OnboardPage(
      title: 'Online / Offline',
      body:
          'Pilih mode:\nOnline: diproses server.\nOffline: diproses di aplikasi.',
      icon: Icons.cloud_done_rounded,
    ),
    _OnboardPage(
      title: 'Siap Mulai',
      body: 'Pastikan pencahayaan cukup dan tangan terlihat jelas di kamera.',
      icon: Icons.videocam_rounded,
    ),
  ];

  void _next() {
    if (_index < _pages.length - 1) {
      _pageController.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _HeaderCard(page: page),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppColors.poppins,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppColors.poppins,
                            fontSize: 15,
                            color: AppColors.mutedText,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),
            _Dots(count: _pages.length, active: _index),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _skip,
                    child: const Text(
                      'Lewati',
                      style: TextStyle(
                        fontFamily: AppColors.poppins,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _next,
                    child: _index == _pages.length - 1
                        ? const Text(
                            'Mulai',
                            style: TextStyle(
                              fontFamily: AppColors.poppins,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right,
                            size: 20,
                            weight: 900,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final _OnboardPage page;
  const _HeaderCard({required this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
            AppColors.primarySoft
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: page.image != null
                ? ClipOval(
                    child: Container(
                      width: 160,
                      height: 160,
                      color: Colors.white.withAlpha(30),
                      child: Image.asset(
                        page.image!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(32),
                    ),
                    child: Icon(
                      page.icon ?? Icons.star_rounded,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == active ? AppColors.primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String title;
  final String body;
  final String? image;
  final IconData? icon;

  const _OnboardPage({
    required this.title,
    required this.body,
    this.image,
    this.icon,
  });
}
