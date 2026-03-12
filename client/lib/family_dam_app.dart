import 'package:mydatatools/app_router.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FamilyDamApp extends StatelessWidget {
  const FamilyDamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      restorationScopeId: 'mydata.tools',
      title: "MyData / Tools",
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.instance,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F3F4), // Google Cloud Gray
        // primaryColor/colorSchemeSeed is mapped to Google Blue
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          surface: Colors.white,
        ),
        dividerColor: Colors.black12,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme).copyWith(
          titleLarge: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          bodyMedium: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
          labelSmall: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        cardTheme: const CardTheme(
          surfaceTintColor: Colors.white,
          color: Colors.white,
          elevation: 1, // subtle shadow like GCP
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ).data,
      ),
    );
  }
}
