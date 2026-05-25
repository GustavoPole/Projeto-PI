import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projeto_pi/providers/app_state.dart';
import 'package:projeto_pi/screens/auth/login_screen.dart';
import 'package:projeto_pi/screens/home/home_screen.dart';

// FIX 3: main é async e aguarda loadFromPrefs ANTES de chamar runApp.
// Isso garante que o token já está no AppState quando qualquer tela
// chamar _loadDbPlan — evitando a requisição com token vazio que fazia
// o plano sumir ao reabrir o app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appState = AppState();
  await appState.loadFromPrefs(); // carrega token, nome, email e foto

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: appState,
      child: const DietHubApp(),
    ),
  );
}

class DietHubApp extends StatelessWidget {
  const DietHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final token = context.read<AppState>().token;

    return MaterialApp(
      title: 'dietHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      // Se já tem token salvo, vai direto para Home; senão, Login.
      home: token.isNotEmpty ? const HomeScreen() : const LoginScreen(),
    );
  }
}
