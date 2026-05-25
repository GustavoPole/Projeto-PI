import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // ── Singleton injetável ────────────────────────────────────────────────────
  // Código de produção usa ApiService.loginUser() — os métodos estáticos
  // delegam para a instância, então MockApiService pode sobrescrever tudo.
  static ApiService _instance = ApiService();
  static ApiService get instance => _instance;
  // ignore: avoid_setters_without_getters
  static set instance(ApiService v) => _instance = v;

  ApiService(); // construtor público — necessário para o mock extender a classe

  // ── URL base ───────────────────────────────────────────────────────────────
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  // ── AUTH ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> registerUser(
    String nome,
    String cpf,
    String email,
    String password,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'nome': nome,
          'cpf': cpf,
          'email': email,
          'password': password,
        }),
      );
      final body = jsonDecode(res.body);
      return res.statusCode == 201
          ? {'success': true, 'message': body['message']}
          : {'success': false, 'message': body['message']};
    } catch (_) {
      return {'success': false, 'message': 'Erro de conexao com o servidor.'};
    }
  }

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final body = jsonDecode(res.body);
      return res.statusCode == 200
          ? {'success': true, 'token': body['token'], 'user': body['user']}
          : {'success': false, 'message': body['message']};
    } catch (_) {
      return {'success': false, 'message': 'Erro de conexao com o servidor.'};
    }
  }

  // ── PERFIL ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? nome,
    String? email,
  }) async {
    try {
      final body = <String, String>{};
      if (nome != null) body['nome'] = nome;
      if (email != null) body['email'] = email;
      final res = await http.put(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      final resBody = jsonDecode(res.body);
      return res.statusCode == 200
          ? {'success': true, 'message': resBody['message']}
          : {'success': false, 'message': resBody['message']};
    } catch (_) {
      return {'success': false, 'message': 'Erro de conexao.'};
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/profile/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      final body = jsonDecode(res.body);
      return res.statusCode == 200
          ? {'success': true, 'message': body['message']}
          : {'success': false, 'message': body['message']};
    } catch (_) {
      return {'success': false, 'message': 'Erro de conexao.'};
    }
  }

  // ── PLANO ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMyPlan(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/my-plan'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Erro ao buscar plano.'};
    }
  }

  static Future<Map<String, dynamic>> savePlan({
    required String token,
    required String goal,
    required double weight,
    required double height,
    required int age,
    required String gender,
    required String activityLevel,
    required double waterGoal,
    required double caloriesGoal,
    required double proteinGoal,
    required double carbsGoal,
    required double fatGoal,
    List<String> allergies = const [],
    List<String> preferences = const [],
    List<String> pathologies = const [],
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/save-plan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'goal': goal,
          'weight': weight,
          'height': height,
          'age': age,
          'gender': gender,
          'activityLevel': activityLevel,
          'waterGoal': waterGoal,
          'caloriesGoal': caloriesGoal,
          'proteinGoal': proteinGoal,
          'carbsGoal': carbsGoal,
          'fatGoal': fatGoal,
          'allergies': allergies,
          'preferences': preferences,
          'pathologies': pathologies,
        }),
      );
      final body = jsonDecode(res.body);
      return res.statusCode == 201 || res.statusCode == 200
          ? {'success': true, 'planId': body['planId']}
          : {'success': false, 'message': body['message']};
    } catch (_) {
      return {'success': false, 'message': 'Erro ao salvar plano.'};
    }
  }

  // ── ALIMENTOS ──────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAlimentos(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/alimentos'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(body['alimentos'] ?? []);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── LOGS DIÁRIOS ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> salvarRefeicao({
    required String token,
    required int alimentoId,
    required double quantidadeG,
    required String tipo,
    String? refeicaoReferencia,
    int? alimentoNovoId,
    String? nome,
    dynamic calorias,
    dynamic proteinas,
    dynamic carbos,
    dynamic gorduras,
  }) async {
    try {
      final payload = <String, dynamic>{
        'alimento_id': alimentoId,
        'quantidade_g': quantidadeG,
        'tipo': tipo,
        'refeicao_referencia': refeicaoReferencia,
        'alimento_novo_id': alimentoNovoId,
      };
      if (nome != null && nome.isNotEmpty) payload['nome'] = nome;
      if (calorias != null) payload['calorias'] = calorias;
      if (proteinas != null) payload['proteinas'] = proteinas;
      if (carbos != null) payload['carbos'] = carbos;
      if (gorduras != null) payload['gorduras'] = gorduras;

      final res = await http.post(
        Uri.parse('$_baseUrl/api/log-refeicao'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      final body = jsonDecode(res.body);
      return res.statusCode == 201
          ? {'success': true, 'message': body['message']}
          : {'success': false, 'message': body['message']};
    } catch (_) {
      return {'success': false, 'message': 'Erro ao salvar refeicao.'};
    }
  }
}
