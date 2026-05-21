import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:projeto_pi/main.dart';
import 'package:projeto_pi/providers/app_state.dart';
import 'package:projeto_pi/screens/scan/scan_plan_screen.dart';
import 'dart:typed_data';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Teste de Integração: Validação de Scan de Plano com IA', () {
    testWidgets('Deve mostrar erro ao tentar analisar um arquivo que não é um plano alimentar', (WidgetTester tester) async {
      // 1. Inicia o app com estado de login simulado
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (context) => AppState(),
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final appState = tester.element(find.byType(MyApp)).read<AppState>();
      appState.setUser('Professor Teste', 'professor@email.com');
      appState.setToken('mock_token_for_demo'); // O backend precisa estar rodando ou o token ser válido
      await tester.pumpAndSettle();

      // 2. Navega para a tela de Scan (assumindo que existe um botão ou rota direta)
      // Para fins de teste direto, vamos empurrar a tela
      await tester.runAsync(() async {
        Navigator.push(
          tester.element(find.byType(MyApp)),
          MaterialPageRoute(builder: (context) => const ScanPlanScreen()),
        );
      });
      await tester.pumpAndSettle();

      expect(find.byType(ScanPlanScreen), findsOneWidget);

      // 3. Simular a seleção de um arquivo inválido
      // Como o FilePicker abre uma janela nativa, em testes de integração 
      // costumamos mockar o estado interno do widget ou usar pacotes de mock.
      // Aqui, vamos encontrar o estado do widget e injetar o arquivo de teste.
      final dynamic state = tester.state(find.byType(ScanPlanScreen));
      
      // Criamos um "arquivo" fake (bytes de um texto qualquer que não é plano)
      // ignore: invalid_use_of_protected_member
      state.setState(() {
        state._file = AnyPlatformFile(
          name: 'foto_aleatoria.png',
          bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
          extension: 'png',
          size: 5,
        );
      });
      await tester.pumpAndSettle();

      // 4. Clicar no botão "Analisar com IA"
      final analyzeButton = find.text('Analisar com IA');
      expect(analyzeButton, findsOneWidget);
      await tester.tap(analyzeButton);
      
      // 5. Aguardar a resposta do backend (pode demorar alguns segundos)
      await tester.pump(const Duration(seconds: 2)); // Inicia análise
      await tester.pumpAndSettle(const Duration(seconds: 10)); // Aguarda retorno

      // 6. Verificar se a mensagem de erro da IA aparece na tela
      expect(find.textContaining('não foi identificado como um plano alimentar'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}

// Classe auxiliar para mockar o arquivo do FilePicker sem abrir a janela nativa
class AnyPlatformFile {
  final String name;
  final Uint8List? bytes;
  final String? extension;
  final int size;
  AnyPlatformFile({required this.name, this.bytes, this.extension, required this.size});
}
