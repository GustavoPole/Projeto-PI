import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:projeto_pi/providers/app_state.dart';
import 'package:projeto_pi/services/api_service.dart';

class LogMealScreen extends StatefulWidget {
  /// Quando fornecido, a tela abre já nessa refeição e
  /// oculta o seletor de abas — o contexto fica travado.
  final String? initialMeal;

  const LogMealScreen({super.key, this.initialMeal});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  late String _selectedMeal;
  bool _isLoading = false;
  bool _isSaving = false;

  // Quando true, o seletor de refeição fica oculto (contexto travado)
  bool get _mealLocked => widget.initialMeal != null;

  final List<String> _mealTypes = [
    'Café da manhã',
    'Lanche da manhã',
    'Almoço',
    'Lanche da tarde',
    'Jantar',
    'Ceia',
  ];

  final List<Map<String, dynamic>> _added = [];

  final List<Map<String, dynamic>> _suggestions = [
    {
      'name': 'Frango grelhado',
      'unit': '100g',
      'cal': 165,
      'p': 31,
      'c': 0,
      'g': 4,
    },
    {
      'name': 'Arroz integral',
      'unit': '100g',
      'cal': 111,
      'p': 3,
      'c': 23,
      'g': 1,
    },
    {
      'name': 'Ovo cozido',
      'unit': '1 unidade',
      'cal': 78,
      'p': 6,
      'c': 1,
      'g': 5,
    },
    {'name': 'Banana', 'unit': '1 média', 'cal': 89, 'p': 1, 'c': 23, 'g': 0},
    {
      'name': 'Iogurte grego',
      'unit': '170g',
      'cal': 100,
      'p': 17,
      'c': 6,
      'g': 0,
    },
    {'name': 'Aveia', 'unit': '40g', 'cal': 148, 'p': 5, 'c': 27, 'g': 3},
    {'name': 'Batata doce', 'unit': '100g', 'cal': 86, 'p': 2, 'c': 20, 'g': 0},
    {'name': 'Salmão', 'unit': '100g', 'cal': 208, 'p': 20, 'c': 0, 'g': 13},
    {
      'name': 'Whey Protein',
      'unit': '30g',
      'cal': 120,
      'p': 24,
      'c': 3,
      'g': 2,
    },
    {
      'name': 'Pão integral',
      'unit': '1 fatia',
      'cal': 69,
      'p': 3,
      'c': 12,
      'g': 1,
    },
    {'name': 'Maçã', 'unit': '1 média', 'cal': 72, 'p': 0, 'c': 19, 'g': 0},
    {
      'name': 'Feijão cozido',
      'unit': '100g',
      'cal': 77,
      'p': 5,
      'c': 14,
      'g': 0,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Herda o contexto passado pelo chamador; se nulo, usa a primeira refeição
    _selectedMeal = widget.initialMeal ?? 'Café da manhã';
  }

  int get _totalCal => _added.fold(0, (s, f) => s + (f['cal'] as int));

  void _addFood(Map<String, dynamic> food) {
    setState(() => _added.add({...food, 'meal': _selectedMeal}));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food['name']} adicionado!'),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _removeFood(int i) => setState(() => _added.removeAt(i));

  /// Persiste cada alimento via API e depois retorna a lista à tela anterior.
  /// BUG 2 corrigido: sem a chamada à API, o dado só ficava no AppState local
  /// e sumia quando _loadDbPlan() atualizava a tela com dados do banco.
  Future<void> _save() async {
    if (_added.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Adicione pelo menos um alimento!'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final state = context.read<AppState>();
    final token = state.token;

    bool anyError = false;

    if (token.isNotEmpty) {
      for (final food in _added) {
        // Quantidade em gramas: extrai número da string "170g", "1 unidade", etc.
        final unitStr = food['unit']?.toString() ?? '100g';
        final qtdG =
            double.tryParse(unitStr.replaceAll(RegExp(r'[^0-9.]'), '')) ??
            100.0;

        // `refeicaoReferencia` = nome legível da refeição ("Café da manhã", "Almoço"...)
        // `tipo` = valor do enum do banco: SEMPRE 'consumido' para registro manual
        // Erro anterior: enviávamos 'cafe_manha', 'almoco' etc. no campo `tipo`,
        // mas o enum da tabela itens_diario só aceita 'planejado','consumido','fuga'.
        // O MySQL rejeitava o INSERT silenciosamente, causando o erro 500.
        final mealKey = food['meal']?.toString() ?? _selectedMeal;

        final result = await ApiService.salvarRefeicao(
          token: token,
          alimentoId: 0,
          quantidadeG: qtdG,
          tipo: 'consumido',
          refeicaoReferencia: mealKey,
          nome: food['name']?.toString(),
          // Envia os macros para o servidor salvar valores reais no banco
          calorias: food['cal'],
          proteinas: food['p'],
          carbos: food['c'],
          gorduras: food['g'],
        );

        if (result['success'] != true) {
          anyError = true;
        }
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (anyError && token.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Alguns alimentos podem não ter sido salvos no servidor. '
            'Verifique sua conexão.',
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Retorna a lista para home_screen atualizar o AppState local também
    Navigator.pop(context, List<Map<String, dynamic>>.from(_added));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: Column(
        children: [
          // ── HEADER ──────────────────────────────────────────────────────────
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
                          color: Colors.white.withValues(alpha: 0.15),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Registrar Refeição',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          // BUG 3: mostra qual refeição está travada
                          if (_mealLocked)
                            Text(
                              _selectedMeal,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_added.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_totalCal kcal',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),

                // BUG 3: seletor de abas só aparece quando NÃO há contexto travado
                if (!_mealLocked) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _mealTypes.length,
                      itemBuilder: (_, i) {
                        final sel = _selectedMeal == _mealTypes[i];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedMeal = _mealTypes[i]),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _mealTypes[i],
                              style: TextStyle(
                                color: sel
                                    ? const Color(0xFF1B5E20)
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── CORPO ───────────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Alimentos adicionados
                  if (_added.isNotEmpty) ...[
                    const Text(
                      'Adicionados',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1B2B1C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._added.asMap().entries.map((e) {
                      final food = e.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2E7D32),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    food['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${food['unit']} • ${food['cal']} kcal • '
                                    'P:${food['p']}g C:${food['c']}g G:${food['g']}g',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 18,
                              ),
                              onPressed: () => _removeFood(e.key),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],

                  // Lista de sugestões
                  const Text(
                    'Alimentos',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1B2B1C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toque para adicionar',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  ..._suggestions.map((food) {
                    final isAdded = _added.any(
                      (f) => f['name'] == food['name'],
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: isAdded ? null : () => _addFood(food),
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isAdded
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                : const Color(0xFFF5F7F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isAdded ? Icons.check : Icons.add,
                            color: isAdded
                                ? const Color(0xFF2E7D32)
                                : Colors.grey[400],
                            size: 20,
                          ),
                        ),
                        title: Text(
                          food['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isAdded
                                ? Colors.grey[400]
                                : const Color(0xFF1B2B1C),
                          ),
                        ),
                        subtitle: Text(
                          '${food['unit']} • ${food['cal']} kcal',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'P: ${food['p']}g',
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'C: ${food['c']}g',
                              style: const TextStyle(
                                color: Color(0xFFE65100),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'G: ${food['g']}g',
                              style: const TextStyle(
                                color: Color(0xFF6A1B9A),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── BOTÃO SALVAR ─────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_isLoading || _isSaving) ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: (_isLoading || _isSaving)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _added.isEmpty
                            ? 'Adicione alimentos acima'
                            : 'Salvar ${_added.length} '
                                  'alimento${_added.length > 1 ? 's' : ''} '
                                  '(+$_totalCal kcal)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
