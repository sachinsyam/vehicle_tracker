import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_navigation.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 🎨 Professional Palette: Slate Blue + Amber
    const seedColor = Color(0xFF2C3E50); 
    const secondaryColor = Color(0xFFE67E22); 

    return MaterialApp(
      title: 'Vehicle Maintenance Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // --- LIGHT THEME ---
      theme: _buildTheme(Brightness.light, seedColor, secondaryColor),

      // --- DARK THEME ---
      darkTheme: _buildTheme(Brightness.dark, seedColor, secondaryColor),

      home: const MainNavigation(),
    );
  }

  ThemeData _buildTheme(Brightness brightness, Color seed, Color secondary) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        secondary: secondary,
        brightness: brightness,
      ),
    );

    final isLight = brightness == Brightness.light;

    return base.copyWith(
      textTheme: GoogleFonts.latoTextTheme(base.textTheme),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.lato(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isLight ? Colors.black87 : Colors.white,
        ),
        iconTheme: IconThemeData(
          color: isLight ? Colors.black87 : Colors.white,
        ),
      ),
      // 👇 FIXED: Better contrast for Light Mode
      cardTheme: CardThemeData(
        // Add shadow in Light Mode to separate from background
        elevation: isLight ? 3 : 0, 
        shadowColor: isLight ? Colors.black.withOpacity(0.15) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            // Slightly darker border for crisp edges
            color: isLight ? Colors.grey.shade300 : Colors.grey.shade800, 
            width: 1,
          ),
        ),
        color: isLight ? Colors.white : const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: isLight 
          ? const Color(0xFFF0F2F5) // Slightly darker grey-blue for better contrast against white cards
          : const Color(0xFF121212),
    );
  }
}