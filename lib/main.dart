import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/camera_provider.dart';

void main() {
  runApp(const BimaApp());
}

class BimaApp extends StatelessWidget {
  const BimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CameraProvider())],
      child: MaterialApp(
        title: 'Bima - Bahasa Isyarat SIBI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF6B35), // Changed to orange
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Poppins',
          // Modern app bar theme
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFF6B35), // Changed to orange
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          // Modern card theme
          cardTheme: CardThemeData(
            elevation: 8,
            shadowColor:
                const Color(0xFFFF6B35).withOpacity(0.2), // Changed to orange
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          // Modern elevated button theme
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35), // Changed to orange
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor:
                  const Color(0xFFFF6B35).withOpacity(0.3), // Changed to orange
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Modern bottom navigation bar theme
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFFFF6B35), // Changed to orange
            unselectedItemColor: Color(0xFF9E9E9E),
            type: BottomNavigationBarType.fixed,
            elevation: 20,
            selectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
