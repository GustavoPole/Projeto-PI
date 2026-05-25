import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiService {
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static Future<Map<String, dynamic>> generatePlan({
    required String goal,
    required double weight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
    required double waterGoal,
    required List<String> allergies,
    required List<String> preferences,
    required List<String> pathologies,
  }) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      return _mockPlan(goal: goal, weight: weight);
    } catch (e) {
      return {'error': 'Erro ao gerar plano: $e'};
    }
  }

  static Future<Map<String, dynamic>> analyzeDietEscape({
    required String foodDescription,
    required double caloriesConsumed,
    required double caloriesGoal,
    required String token,
    double proteinGoal = 0,
    double carbsGoal = 0,
    double fatGoal = 0,
    List<Map<String, dynamic>> planMeals = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/diet-escape'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'foodDescription': foodDescription,
          'caloriesConsumed': caloriesConsumed,
          'caloriesGoal': caloriesGoal,
          'proteinGoal': proteinGoal,
          'carbsGoal': carbsGoal,
          'fatGoal': fatGoal,
          'planMeals': planMeals,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'analysis': data['analysis']};
        }
      }
      return {'success': false, 'error': 'Erro ao analisar fuga.'};
    } catch (e) {
      return {'success': false, 'error': 'Erro de conexao: $e'};
    }
  }

  static Future<List<Map<String, dynamic>>> suggestFoodSwap({
    required String foodName,
    required String goal,
    required List<String> allergies,
    required List<String> preferences,
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/food-swap'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'foodName': foodName,
          'goal': goal,
          'allergies': allergies,
          'preferences': preferences,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['swaps'] != null) {
          return List<Map<String, dynamic>>.from(data['swaps']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Registra a troca no servidor: novo alimento em [alimentos] + linha em [logs_diarios].
  static Future<Map<String, dynamic>> acceptFoodSwap({
    required String token,
    required String data,
    required int itemRefeicaoBaseId,
    required Map<String, dynamic> novoAlimento,
    dynamic alimentoOriginalId,
    dynamic
    itemDiarioId, // id da linha em itens_diario (trocas manuais efêmeras)
  }) async {
    try {
      final payload = <String, dynamic>{
        'data': data,
        'item_refeicao_base_id': itemRefeicaoBaseId,
        'novoAlimento': novoAlimento,
      };
      if (alimentoOriginalId != null)
        payload['alimento_original_id'] = alimentoOriginalId;
      if (itemDiarioId != null) payload['item_diario_id'] = itemDiarioId;
      final response = await http.post(
        Uri.parse('$_baseUrl/api/accept-food-swap'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      Map<String, dynamic> body = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      }
      if (response.statusCode == 200 && body['success'] == true) {
        return body;
      }
      return {
        'success': false,
        'message':
            body['message']?.toString() ?? 'Erro HTTP ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Map<String, dynamic> _mockPlan({
    required String goal,
    required double weight,
  }) {
    return {
      'success': true,
      'plan': {
        'summary': 'Plano personalizado gerado para seu objetivo de $goal',
        'meals': [
          {
            'name': 'Café da manhã',
            'time': '07:00',
            'foods': [
              '3 ovos mexidos',
              '2 fatias de pão integral',
              'Café sem açúcar',
            ],
            'calories': 420,
          },
          {
            'name': 'Lanche da manhã',
            'time': '10:00',
            'foods': ['1 banana', '30g de aveia'],
            'calories': 230,
          },
          {
            'name': 'Almoço',
            'time': '12:30',
            'foods': [
              '150g frango grelhado',
              '100g arroz integral',
              'Salada à vontade',
            ],
            'calories': 520,
          },
          {
            'name': 'Lanche da tarde',
            'time': '15:30',
            'foods': ['170g iogurte grego', '1 maçã'],
            'calories': 180,
          },
          {
            'name': 'Jantar',
            'time': '19:00',
            'foods': ['100g salmão', '100g batata doce', 'Brócolis no vapor'],
            'calories': 380,
          },
        ],
      },
    };
  }
}
