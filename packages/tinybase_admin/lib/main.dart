import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/connection_provider.dart';
import 'screens/connect_screen.dart';
import 'screens/home_shell.dart';

void main() {
  runApp(const AdminApp());
}

/// Thème partagé clair/sombre — même palette, seule la luminosité change.
/// Police Lexend partout (via google_fonts, chargée à la volée depuis
/// Google Fonts — pas besoin d'embarquer les fichiers .ttf).
ThemeData _buildTheme(Brightness brightness) {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3762F0), brightness: brightness);
  return base.copyWith(textTheme: GoogleFonts.lexendTextTheme(base.textTheme));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ConnectionProvider()..tryRestoreSession(),
      child: MaterialApp(
        title: 'TinyBase Admin',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    if (connection.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return connection.isConnected ? const HomeShell() : const ConnectScreen();
  }
}
