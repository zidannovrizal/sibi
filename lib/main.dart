import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/camera_provider.dart';
import 'providers/server_config_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // Jika .env tidak tersedia, lanjutkan tanpa menahan startup.
  }
  runApp(const BimaApp());
}

class BimaApp extends StatelessWidget {
  const BimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraProvider()),
        ChangeNotifierProvider(create: (_) => ServerConfigProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          final seed = const Color(0xFFFF6B35);
          return MaterialApp(
            title: 'Tangan Nusantara - Bahasa Isyarat SIBI',
            themeMode: themeProv.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'Poppins',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Color(0xFFFF6B35),
                unselectedItemColor: Color(0xFF9E9E9E),
                type: BottomNavigationBarType.fixed,
                elevation: 12,
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: seed,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              fontFamily: 'Poppins',
              appBarTheme: AppBarTheme(
                backgroundColor: seed,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
              ),
            ),
            home: const OnboardingScreen(),
            routes: {
              '/home': (_) => const HomeScreen(),
              '/vocabulary': (_) => const HomeScreen(initialIndex: 1),
              '/settings': (_) => const HomeScreen(initialIndex: 2),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
