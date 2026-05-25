import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projeto_pi/providers/app_state.dart';
import 'package:projeto_pi/services/ai_service.dart';

class DietEscapeScreen extends StatefulWidget {
  const DietEscapeScreen({super.key});

  @override
  State<DietEscapeScreen> createState() => _DietEscapeScreenState();
}

class _DietEscapeScreenState extends State<DietEscapeScreen> {
  final _foodCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _analysis;
  String? _error;

  @override
  void dispose() {
    _foodCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final food = _foodCtrl.text.trim();
    if (food.isEmpty) return;
    final state = context.read<AppState>();

    setState(() {
      _loading = true;
      _analysis = null;
      _error = null;
    });

    final result = await AiService.analyzeDietEscape(
      foodDescription: food,
      caloriesConsumed: state.caloriesConsumed,
      caloriesGoal: state.caloriesGoal,
      proteinGoal: state.proteinGoal,
      carbsGoal: state.carbsGoal,
      fatGoal: state.fatGoal,
      token: state.token,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _analysis = result['analysis'] as Map<String, dynamic>?;
      } else {
        _error = result['error']?.toString() ?? 'Erro ao analisar.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);
    const greenLight = Color(0xFFE8F5E9);
    final state = context.watch<AppState>();

    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fastfood_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fuga da Dieta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Analise e compensacao com IA',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Campo de busca
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _foodCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _analyze(),
                          decoration: const InputDecoration(
                            hintText: 'Ex: 2 fatias de pizza, 1 hamburguer...',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _loading ? null : _analyze,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Analisar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conteudo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: green),
                            SizedBox(height: 16),
                            Text(
                              'Consultando a IA...',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _error != null
                  ? _buildError(_error!)
                  : _analysis != null
                  ? _buildResult(_analysis!, state, green, greenLight)
                  : _buildEmpty(green, greenLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color green, Color greenLight) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.fastfood_outlined,
              size: 52,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Fugiu da dieta?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Sem problemas! Digite o que comeu e a IA vai:\n\n'
            '• Estimar as calorias do alimento\n'
            '• Calcular o impacto na sua meta\n'
            '• Sugerir ajustes nas proximas refeicoes\n'
            '• Dar prioridade aos lanches primeiro',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String err) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.orange),
          const SizedBox(height: 16),
          Text(
            err,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _analyze,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
            child: const Text(
              'Tentar novamente',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(
    Map<String, dynamic> analysis,
    AppState state,
    Color green,
    Color greenLight,
  ) {
    final foodCal = (analysis['foodCalories'] as num?)?.toInt() ?? 0;
    final portion = analysis['foodPortion']?.toString() ?? '';
    final message = analysis['message']?.toString() ?? '';
    final motivation = analysis['motivation']?.toString() ?? '';
    final suggestion = analysis['suggestion']?.toString() ?? '';
    final adjustments = (analysis['adjustments'] as List?)?.cast<Map>() ?? [];
    final remaining = (state.caloriesGoal - state.caloriesConsumed - foodCal)
        .toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card do alimento
        _card(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.fastfood,
                  color: Colors.orange[700],
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _foodCtrl.text.trim(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (portion.isNotEmpty)
                      Text(
                        portion,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '~$foodCal kcal',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Impacto nas metas
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Impacto nas metas de hoje', green),
              const SizedBox(height: 12),
              _progressRow(
                'Calorias',
                state.caloriesConsumed + foodCal,
                state.caloriesGoal,
                const Color(0xFFE53935),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat(
                    'Consumidas',
                    '${(state.caloriesConsumed + foodCal).toInt()} kcal',
                    Colors.grey[700]!,
                  ),
                  _miniStat(
                    'Meta',
                    '${state.caloriesGoal.toInt()} kcal',
                    green,
                  ),
                  _miniStat(
                    'Saldo',
                    '${remaining > 0 ? remaining : 0} kcal',
                    remaining >= 0 ? green : Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Mensagem da IA
        if (message.isNotEmpty)
          _card(
            color: greenLight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: green, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (message.isNotEmpty) const SizedBox(height: 12),

        // Ajustes sugeridos
        if (adjustments.isNotEmpty) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Compensacoes sugeridas', green),
                const SizedBox(height: 4),
                Text(
                  'Priorizando lanches antes das refeicoes principais',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 12),
                ...adjustments.map((adj) {
                  final meal = adj['meal']?.toString() ?? '';
                  final food = adj['food']?.toString() ?? '';
                  final amount = adj['amount']?.toString() ?? '';
                  final isReduce = (adj['type']?.toString() ?? '') != 'add';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isReduce ? Colors.red[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isReduce
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isReduce
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          color: isReduce ? Colors.red[700] : Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (meal.isNotEmpty)
                                Text(
                                  meal,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              Text(
                                food,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isReduce
                                ? Colors.red[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            amount,
                            style: TextStyle(
                              color: isReduce
                                  ? Colors.red[800]
                                  : Colors.blue[800],
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Sugestao de refeicao
        if (suggestion.isNotEmpty) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Sugestao para o restante do dia', green),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: greenLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu,
                        color: Color(0xFF2E7D32),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Motivacao
        if (motivation.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('💪', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    motivation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        // Botao nova analise
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              _foodCtrl.clear();
              setState(() {
                _analysis = null;
                _error = null;
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Nova analise'),
            style: OutlinedButton.styleFrom(
              foregroundColor: green,
              side: const BorderSide(color: Color(0xFF2E7D32)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: color == null
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text, Color color) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
    );
  }

  Widget _progressRow(String label, double current, double goal, Color color) {
    final pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '${current.toInt()} / ${goal.toInt()} kcal',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              pct >= 1.0 ? Colors.orange : color,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
