import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projeto_pi/providers/app_state.dart';
import 'package:projeto_pi/services/api_service.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _waterController = TextEditingController(text: '2.5');
  String _gender = 'Masculino';
  String _activityLevel = 'Sedentário';
  String _goal = 'Emagrecimento';
  final List<String> _allergies = [];
  final List<String> _preferences = [];
  final List<String> _pathologies = [];

  final _allergyOptions = [
    'Glúten',
    'Lactose',
    'Amendoim',
    'Frutos do mar',
    'Ovos',
    'Soja',
    'Nozes',
    'Trigo',
  ];
  final _preferenceOptions = [
    'Vegano',
    'Vegetariano',
    'Low Carb',
    'Paleo',
    'Cetogênica',
    'Mediterrânea',
    'Sem restrições',
  ];
  final _pathologyOptions = [
    'Diabetes',
    'Hipertensão',
    'Gastrite',
    'Colesterol alto',
    'Hipotireoidismo',
    'Intestino irritável',
    'Nenhuma',
  ];

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _waterController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    } else {
      _generatePlan();
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _generatePlan() async {
    setState(() => _isLoading = true);

    final state = context.read<AppState>();

    // Captura o token ANTES de qualquer await para evitar condição de corrida
    final token = state.token;

    // Valores locais para não depender dos controllers após await
    final double weight = double.tryParse(_weightController.text) ?? 70;
    final double height = double.tryParse(_heightController.text) ?? 170;
    final int age = int.tryParse(_ageController.text) ?? 25;
    final double waterGoal = double.tryParse(_waterController.text) ?? 2.5;

    // 1. Salva localmente no Provider (calcula metas Harris-Benedict)
    state.setPlan(
      goal: _goal,
      weight: weight,
      height: height,
      age: age,
      gender: _gender,
      activityLevel: _activityLevel,
      waterGoal: waterGoal,
      allergies: _allergies,
      preferences: _preferences,
    );

    // 2. Salva no banco via API para persistir entre sessões
    bool savedToDb = false;
    String? dbError;
    if (token.isNotEmpty) {
      try {
        final result = await ApiService.savePlan(
          token: token,
          goal: _goal,
          weight: weight,
          height: height,
          age: age,
          gender: _gender,
          activityLevel: _activityLevel,
          waterGoal: waterGoal,
          caloriesGoal: state.caloriesGoal,
          proteinGoal: state.proteinGoal,
          carbsGoal: state.carbsGoal,
          fatGoal: state.fatGoal,
          allergies: _allergies,
          preferences: _preferences,
          pathologies: _pathologies,
        );
        savedToDb = result['success'] == true;
        if (!savedToDb) {
          dbError = result['message']?.toString();
        }
      } catch (e) {
        dbError = e.toString();
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!savedToDb && dbError != null) {
      // Avisa o usuário mas ainda permite continuar (plano salvo localmente)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plano salvo localmente. Erro ao sincronizar: $dbError',
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }

    Navigator.pop(context, true);
  }

  bool _canProceed() {
    if (_currentPage == 0) {
      return _ageController.text.isNotEmpty &&
          _weightController.text.isNotEmpty &&
          _heightController.text.isNotEmpty;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: Column(
        children: [
          // HEADER
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 12,
              16,
              20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Criar Plano Alimentar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_currentPage + 1}/4',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: i <= _currentPage
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _stepLabel(0, 'Dados'),
                    _stepLabel(1, 'Atividade'),
                    _stepLabel(2, 'Objetivo'),
                    _stepLabel(3, 'Perfil'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_page1(), _page2(), _page3(), _page4()],
            ),
          ),

          // BOTÕES
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentPage > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prev,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Voltar',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canProceed() ? _next : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentPage < 3 ? 'Continuar' : 'Gerar Plano',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLabel(int step, String label) {
    final active = step <= _currentPage;
    return Text(
      label,
      style: TextStyle(
        color: active ? Colors.white : Colors.white.withOpacity(0.5),
        fontSize: 11,
        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  // PÁGINA 1 — Dados
  Widget _page1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _sectionTitle(
            '📏 Dados Antropométricos',
            'Usados para calcular seu metabolismo basal',
          ),
          const SizedBox(height: 20),
          _label('Gênero Biológico'),
          const SizedBox(height: 8),
          Row(
            children: ['Masculino', 'Feminino'].map((g) {
              final sel = _gender == g;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _gender = g),
                  child: Container(
                    margin: EdgeInsets.only(right: g == 'Masculino' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFF2E7D32) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF2E7D32)
                            : Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          g == 'Masculino' ? Icons.male : Icons.female,
                          color: sel ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          g,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _label('Idade'),
          const SizedBox(height: 8),
          _input(
            _ageController,
            'Ex: 25',
            TextInputType.number,
            Icons.cake_outlined,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Peso (kg)'),
                    const SizedBox(height: 8),
                    _input(
                      _weightController,
                      'Ex: 70',
                      TextInputType.number,
                      Icons.monitor_weight_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Altura (cm)'),
                    const SizedBox(height: 8),
                    _input(
                      _heightController,
                      'Ex: 175',
                      TextInputType.number,
                      Icons.height,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // PÁGINA 2 — Atividade
  Widget _page2() {
    final levels = [
      {
        'label': 'Sedentário',
        'desc': 'Pouco ou nenhum exercício',
        'icon': Icons.chair_outlined,
      },
      {
        'label': 'Levemente Ativo',
        'desc': 'Exercício leve 1-3 dias/semana',
        'icon': Icons.directions_walk,
      },
      {
        'label': 'Moderadamente Ativo',
        'desc': 'Exercício moderado 3-5 dias/semana',
        'icon': Icons.directions_bike,
      },
      {
        'label': 'Muito Ativo',
        'desc': 'Exercício pesado 6-7 dias/semana',
        'icon': Icons.fitness_center,
      },
      {
        'label': 'Atleta',
        'desc': 'Treinos intensos diários',
        'icon': Icons.emoji_events,
      },
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _sectionTitle(
            '🏃 Nível de Atividade Física',
            'Selecione o que melhor descreve sua rotina',
          ),
          const SizedBox(height: 20),
          ...levels.map((l) {
            final sel = _activityLevel == l['label'];
            return GestureDetector(
              onTap: () =>
                  setState(() => _activityLevel = l['label'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFF2E7D32).withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sel
                        ? const Color(0xFF2E7D32)
                        : Colors.grey.withOpacity(0.2),
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF2E7D32).withOpacity(0.1)
                            : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        l['icon'] as IconData,
                        color: sel ? const Color(0xFF2E7D32) : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l['label'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? const Color(0xFF1B5E20)
                                  : const Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l['desc'] as String,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sel)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // PÁGINA 3 — Objetivo
  Widget _page3() {
    final goals = [
      {
        'label': 'Emagrecimento',
        'desc': 'Déficit calórico para perda de peso saudável',
        'icon': Icons.trending_down,
        'color': const Color(0xFFE65100),
      },
      {
        'label': 'Manutenção',
        'desc': 'Manter o peso atual de forma saudável',
        'icon': Icons.balance,
        'color': const Color(0xFF1565C0),
      },
      {
        'label': 'Ganho de Massa',
        'desc': 'Superávit calórico e foco em proteínas',
        'icon': Icons.trending_up,
        'color': const Color(0xFF2E7D32),
      },
      {
        'label': 'Melhora da Performance',
        'desc': 'Foco em energia para treinos intensos',
        'icon': Icons.bolt,
        'color': const Color(0xFF6A1B9A),
      },
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _sectionTitle(
            '🎯 Objetivo Nutricional',
            'O que você quer alcançar com seu plano?',
          ),
          const SizedBox(height: 20),
          ...goals.map((g) {
            final sel = _goal == g['label'];
            final color = g['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _goal = g['label'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: sel ? color.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sel ? color : Colors.grey.withOpacity(0.2),
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        g['icon'] as IconData,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g['label'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: sel ? color : const Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            g['desc'] as String,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (sel) Icon(Icons.check_circle, color: color, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // PÁGINA 4 — Perfil Clínico
  Widget _page4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _sectionTitle(
            '🏥 Perfil Clínico e Restrições',
            'Para personalizar seu plano com segurança',
          ),
          const SizedBox(height: 20),
          _label('Alergias ou Intolerâncias'),
          const SizedBox(height: 8),
          _chips(_allergyOptions, _allergies),
          const SizedBox(height: 20),
          _label('Preferências Alimentares'),
          const SizedBox(height: 8),
          _chips(_preferenceOptions, _preferences),
          const SizedBox(height: 20),
          _label('Patologias'),
          const SizedBox(height: 8),
          _chips(_pathologyOptions, _pathologies),
          const SizedBox(height: 20),
          _label('Meta de Hidratação (litros/dia)'),
          const SizedBox(height: 8),
          _input(
            _waterController,
            'Ex: 2.5',
            const TextInputType.numberWithOptions(decimal: true),
            Icons.water_drop_outlined,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF2E7D32).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ao clicar em "Gerar Plano", criaremos um plano alimentar personalizado com suas metas calóricas e de macronutrientes calculadas.',
                    style: TextStyle(
                      color: const Color(0xFF1B5E20).withOpacity(0.8),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chips(List<String> options, List<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final sel = selected.contains(opt);
        return GestureDetector(
          onTap: () => setState(() {
            if (sel)
              selected.remove(opt);
            else
              selected.add(opt);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFF2E7D32) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel
                    ? const Color(0xFF2E7D32)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: sel ? Colors.white : Colors.grey[600],
                fontSize: 13,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2B1C),
          ),
        ),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF37474F),
    ),
  );

  Widget _input(
    TextEditingController ctrl,
    String hint,
    TextInputType type,
    IconData icon,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
