import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:projeto_pi/providers/app_state.dart';
import 'package:projeto_pi/screens/auth/login_screen.dart';
import 'package:projeto_pi/screens/plan/create_plan_screen.dart';
import 'package:projeto_pi/screens/log/log_meal_screen.dart';
import 'package:projeto_pi/services/ai_service.dart';
import 'package:projeto_pi/services/api_service.dart';
import 'package:projeto_pi/screens/scan/scan_plan_screen.dart';
import 'package:projeto_pi/screens/home/fuga_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fade;

  final _swapController = TextEditingController();
  List<Map<String, dynamic>> _swapResults = [];
  bool _swapLoading = false;
  String _swapError = '';
  bool _swapSearched = false;

  Map<String, dynamic>? _swapPlanContext;
  bool _swapAccepting = false;

  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  bool _planLoading = true;
  Map<String, dynamic>? _dbPlan;

  String _todayIso() {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  Future<void> _loadDbPlan() async {
    final state = context.read<AppState>();
    final token = state.token;
    if (token.isEmpty) {
      if (mounted) setState(() => _planLoading = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse(
          '$_baseUrl/api/my-plan?date=${Uri.encodeQueryComponent(_todayIso())}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            if (data['success'] == true && data['hasPlan'] == true) {
              _dbPlan = Map<String, dynamic>.from(data['plan']);
              final metas = data['plan']?['resumo_nutricional']?['metas'];
              final meta = data['plan_meta'];
              if (metas != null) {
                state.setPlanFromDb(
                  caloriesGoal: (metas['calorias'] as num?)?.toDouble() ?? 0,
                  proteinGoal: (metas['proteinas'] as num?)?.toDouble() ?? 0,
                  carbsGoal: (metas['carbos'] as num?)?.toDouble() ?? 0,
                  fatGoal: (metas['gordura'] as num?)?.toDouble() ?? 0,
                  waterGoal: meta != null
                      ? (double.tryParse(
                              meta['waterGoal']?.toString() ?? '2.5',
                            ) ??
                            2.5)
                      : 2.5,
                  goal: meta?['goal'] ?? '',
                  weight:
                      double.tryParse(meta?['weight']?.toString() ?? '0') ?? 0,
                  height:
                      double.tryParse(meta?['height']?.toString() ?? '0') ?? 0,
                  age: int.tryParse(meta?['age']?.toString() ?? '0') ?? 0,
                  gender: meta?['gender'] ?? '',
                  activityLevel: meta?['activityLevel'] ?? '',
                );
              }
            } else {
              _dbPlan = null;
            }
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _planLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDbPlan());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _swapController.dispose();
    super.dispose();
  }

  // ---- Formata quantidade: <1000g → "500g", >=1000g → "1kg" / "1.2kg" ----
  String _formatQtd(dynamic raw) {
    final g = double.tryParse(raw?.toString() ?? '0') ?? 0;
    if (g >= 1000) {
      final kg = g / 1000;
      final s = kg == kg.roundToDouble()
          ? kg.toInt().toString()
          : kg.toStringAsFixed(1);
      return '${s}kg';
    }
    return '${g.toStringAsFixed(0)}g';
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sair da conta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              context
                  .read<AppState>()
                  .clearUser(); // chamada async — não bloqueia navegação
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Sair', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: FadeTransition(
        opacity: _fade,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomePage(),
            _buildFugasPage(),
            _buildTrocasPage(),
            _buildPerfilPage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ==========================================
  // HOME PAGE
  // ==========================================
  Widget _buildHomePage() {
    final state = context.watch<AppState>();
    final firstName = state.userName.isNotEmpty
        ? state.userName.split(' ')[0]
        : 'você';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 124,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF1B5E20),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 8,
                12,
                10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, $firstName! 👋',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                        const Text(
                          'dietHub',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: _logout,
                    tooltip: 'Sair',
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_planLoading)
                  _buildPlanLoadingCard()
                else if (_dbPlan != null)
                  _buildDbPlanSection(_dbPlan!)
                else if (state.hasPlan) ...[
                  _buildCaloriesCard(state),
                  const SizedBox(height: 16),
                  _buildMacrosRow(state),
                  const SizedBox(height: 16),
                  _buildWaterCard(state),
                  const SizedBox(height: 16),
                  _buildMealsSection(state),
                ] else
                  _buildNoPlanCard(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoPlanCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Crie seu plano\nalimentar personalizado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Preencha seus dados e receba um plano\ncompleto adaptado aos seus objetivos.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
                );
                if (result == true && mounted) {
                  setState(() {
                    _planLoading = true;
                    _dbPlan = null;
                  });
                  await _loadDbPlan();
                }
              },
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF1B5E20),
              ),
              label: const Text(
                'Criar Plano Alimentar',
                style: TextStyle(
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: Color(0xFF2E7D32)),
          SizedBox(height: 16),
          Text(
            'Carregando seu plano alimentar...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PLANO DO BANCO
  // ==========================================
  double _dbItemScaleFactor(Map<String, dynamic> al) {
    final qtd = (al['quantidade_g'] as num?)?.toDouble() ?? 0;
    final porc = double.tryParse(al['porcao_g']?.toString() ?? '100') ?? 100;
    return porc > 0 ? qtd / porc : 1;
  }

  double _dbScaledValue(Map<String, dynamic> al, String macroKey) {
    final base = double.tryParse(al[macroKey]?.toString() ?? '0') ?? 0;
    return base * _dbItemScaleFactor(al);
  }

  Widget _buildDbPlanNutritionSummary(
    Map<String, dynamic> plan,
    Color green,
    Color greenLight,
  ) {
    final raw = plan['resumo_nutricional'];
    if (raw == null || raw is! Map) return const SizedBox.shrink();

    final r = Map<String, dynamic>.from(raw);
    // calorias_total = soma de tudo que o servidor devolveu (plano base + manuais do dia)
    final calTotal = (r['calorias_total'] as num?)?.round() ?? 0;
    final pG = (r['proteinas_g'] as num?)?.toDouble() ?? 0;
    final cG = (r['carbos_g'] as num?)?.toDouble() ?? 0;
    final gG = (r['gorduras_g'] as num?)?.toDouble() ?? 0;

    final pctRaw = r['distribuicao_pct'];
    final pct = pctRaw is Map
        ? Map<String, dynamic>.from(pctRaw)
        : <String, dynamic>{};
    var pPct = (pct['proteina'] as num?)?.round() ?? 0;
    var cPct = (pct['carboidrato'] as num?)?.round() ?? 0;
    var gPct = (pct['gordura'] as num?)?.round() ?? 0;
    if (pPct + cPct + gPct > 100) gPct = 100 - pPct - cPct;

    final metasRaw = r['metas'];
    Map<String, dynamic>? metas;
    if (metasRaw is Map) metas = Map<String, dynamic>.from(metasRaw);
    final metaCal = metas != null ? (metas['calorias'] as num?)?.round() : null;

    // Sincroniza o AppState com os valores consumidos vindos do banco
    // para que _buildCaloriesCard (se exibido) e outros cards fiquem corretos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final st = context.read<AppState>();
      if (metaCal != null && metaCal > 0 && st.caloriesGoal == 0) {
        st.setPlanFromDb(
          caloriesGoal: metaCal.toDouble(),
          proteinGoal: metas?['proteinas'] != null
              ? (metas!['proteinas'] as num).toDouble()
              : 0,
          carbsGoal: metas?['carbos'] != null
              ? (metas!['carbos'] as num).toDouble()
              : 0,
          fatGoal: metas?['gordura'] != null
              ? (metas!['gordura'] as num).toDouble()
              : 0,
          waterGoal: st.waterGoal,
        );
      }
    });

    const blue = Color(0xFF1565C0);
    const orange = Color(0xFFE65100);
    const purple = Color(0xFF6A1B9A);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_outline, color: green, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Macronutrientes do plano',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Linha: consumido / meta
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$calTotal',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: green,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'kcal consumidas',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (metaCal != null && metaCal > 0) ...[
                const Spacer(),
                Flexible(
                  child: Text(
                    'Meta: $metaCal kcal',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ],
          ),
          // Barra de progresso: consumido vs meta
          if (metaCal != null && metaCal > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (calTotal / metaCal).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  calTotal >= metaCal ? Colors.orange : green,
                ),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consumidas: $calTotal kcal',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                Text(
                  'Restantes: ${(metaCal - calTotal).clamp(0, metaCal)} kcal',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
          if (pPct + cPct + gPct > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (pPct > 0)
                      Expanded(
                        flex: pPct.clamp(1, 100),
                        child: Container(color: blue),
                      ),
                    if (cPct > 0)
                      Expanded(
                        flex: cPct.clamp(1, 100),
                        child: Container(color: orange),
                      ),
                    if (gPct > 0)
                      Expanded(
                        flex: gPct.clamp(1, 100),
                        child: Container(color: purple),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _dbMacroChip('Proteínas', pG, pPct, blue, greenLight),
              _dbMacroChip('Carboidratos', cG, cPct, orange, greenLight),
              _dbMacroChip('Gorduras', gG, gPct, purple, greenLight),
            ],
          ),
          if (metas != null &&
              (((metas['proteinas'] as num?) ?? 0) > 0 ||
                  ((metas['carbos'] as num?) ?? 0) > 0 ||
                  ((metas['gordura'] as num?) ?? 0) > 0)) ...[
            const SizedBox(height: 10),
            Text(
              'Metas (g/dia): P ${(metas['proteinas'] as num?)?.toStringAsFixed(0) ?? '—'}  •  C ${(metas['carbos'] as num?)?.toStringAsFixed(0) ?? '—'}  •  G ${(metas['gordura'] as num?)?.toStringAsFixed(0) ?? '—'}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _dbMacroChip(
    String label,
    double grams,
    int pct,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${grams.toStringAsFixed(grams >= 10 ? 0 : 1)} g',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            '~$pct% kcal',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildDbPlanSection(Map<String, dynamic> plan) {
    const green = Color(0xFF2E7D32);
    const greenLight = Color(0xFFE8F5E9);
    final refeicoes = (plan['refeicoes'] as List?) ?? [];
    final dataCriacao = plan['data_criacao']?.toString().split('T')[0] ?? '';

    String nomePlano = plan['nome']?.toString() ?? 'Plano Alimentar';
    try {
      if (nomePlano.startsWith('{')) {
        final decoded = jsonDecode(nomePlano);
        nomePlano = 'Plano ${decoded['goal'] ?? 'Alimentar'}';
      }
    } catch (_) {}

    // Categorias padrão — sempre exibidas, com ou sem scan
    final refeicoesPadrao = [
      {'nome': 'Café da Manhã', 'horario': '07:00', 'alimentos': [], 'id': -1},
      {
        'nome': 'Lanche da Manhã',
        'horario': '10:00',
        'alimentos': [],
        'id': -2,
      },
      {'nome': 'Almoço', 'horario': '12:30', 'alimentos': [], 'id': -3},
      {'nome': 'Café da Tarde', 'horario': '15:30', 'alimentos': [], 'id': -4},
      {'nome': 'Janta', 'horario': '19:00', 'alimentos': [], 'id': -5},
      {'nome': 'Ceia', 'horario': '21:00', 'alimentos': [], 'id': -6},
    ];

    // Verifica se há refeições reais do scan (id numérico positivo)
    final temScan = refeicoes.any((r) {
      final id = (r as Map)['id'];
      if (id is int) return id > 0;
      if (id is String) return int.tryParse(id) != null && int.parse(id) > 0;
      return false;
    });

    late final List<Map> listaRefeicoes;

    if (temScan) {
      // Tem scan: mostra SÓ as refeições do scan, sem misturar com padrão
      // (o scan já tem os nomes corretos do plano do usuário)
      listaRefeicoes = List<Map>.from(refeicoes.map((r) => r as Map));
    } else if (refeicoes.isNotEmpty) {
      // Tem só itens manuais (refeições virtuais): mescla com padrão
      // para garantir que as 6 categorias apareçam
      final Map<String, Map> refBancoPorNome = {};
      for (final r in refeicoes) {
        final chave = (r as Map)['nome']?.toString().toLowerCase().trim() ?? '';
        if (chave.isNotEmpty) refBancoPorNome[chave] = r;
      }
      final result = <Map>[];
      final nomesUsados = <String>{};
      for (final padrao in refeicoesPadrao) {
        final chave = padrao['nome']!.toString().toLowerCase().trim();
        result.add(refBancoPorNome[chave] ?? padrao);
        nomesUsados.add(chave);
      }
      for (final r in refeicoes) {
        final chave = (r as Map)['nome']?.toString().toLowerCase().trim() ?? '';
        if (chave.isNotEmpty && !nomesUsados.contains(chave)) result.add(r);
      }
      listaRefeicoes = result;
    } else {
      // Sem nada: mostra as 6 categorias padrão vazias
      listaRefeicoes = refeicoesPadrao;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho clicável para recarregar
        GestureDetector(
          onTap: () {
            setState(() {
              _planLoading = true;
              _dbPlan = null;
            });
            _loadDbPlan();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: green.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomePlano,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dataCriacao.isNotEmpty)
                        Text(
                          'Criado em $dataCriacao  •  ${refeicoes.length} refeições',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.refresh, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),

        _buildDbPlanNutritionSummary(plan, green, greenLight),

        const Text(
          'Refeições do plano',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),

        // Banner informativo apenas quando nenhuma refeição veio do banco
        // (sem scan e sem itens manuais ainda)
        if (refeicoes.every(
          (r) => ((r as Map)['alimentos'] as List?)?.isEmpty ?? true,
        ))
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Use o Scan ou "Adicionar alimento" para registrar '
                    'suas refeições do dia.',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

        ...listaRefeicoes.asMap().entries.map((entry) {
          final i = entry.key;
          final ref = entry.value as Map;
          // DbMealCard: refeição do banco (scan ou virtual com alimentos)
          // EmptyMealCard: categoria padrão sem alimentos ainda
          final temAlimentos = (ref['alimentos'] as List?)?.isNotEmpty == true;
          final ehDoScan = ref['id'] is int && (ref['id'] as int) > 0;
          return (temAlimentos || ehDoScan)
              ? _buildDbMealCard(ref, i, green, greenLight)
              : _buildEmptyMealCard(ref, i, green, greenLight);
        }),
      ],
    );
  }

  // ---- Card de refeição vazia com botão + funcional ----
  Widget _buildEmptyMealCard(Map ref, int idx, Color green, Color greenLight) {
    final icons = [
      Icons.wb_sunny_outlined,
      Icons.local_cafe_outlined,
      Icons.lunch_dining,
      Icons.free_breakfast_outlined,
      Icons.dinner_dining,
      Icons.nightlight_outlined,
    ];
    final icon = icons[idx % icons.length];
    final nome = ref['nome']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: greenLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: green, size: 20),
          ),
          title: Text(
            nome,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            ref['horario']?.toString() ?? '',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nenhum alimento cadastrado.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // CORREÇÃO: botão + agora abre o LogMealScreen
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LogMealScreen(initialMeal: nome),
                              ),
                            );
                            if (result != null &&
                                result is List<Map<String, dynamic>> &&
                                mounted) {
                              context.read<AppState>().addMeals(result);
                              setState(() {
                                _planLoading = true;
                                _dbPlan = null;
                              });
                              await _loadDbPlan();
                            }
                          },
                          icon: Icon(Icons.add, color: green, size: 18),
                          label: Text(
                            'Adicionar alimento',
                            style: TextStyle(
                              color: green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: green),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ScanPlanScreen(),
                            ),
                          ).then((_) {
                            setState(() {
                              _planLoading = true;
                              _dbPlan = null;
                            });
                            _loadDbPlan();
                          });
                        },
                        icon: Icon(
                          Icons.document_scanner_outlined,
                          color: green,
                          size: 18,
                        ),
                        label: Text(
                          'Scan',
                          style: TextStyle(
                            color: green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSwapFromPlan({
    required int itemRefeicaoBaseId,
    required String nomeParaBusca,
    int? alimentoOriginalId,
    int? itemDiarioId,
    dynamic quantidadeG, // quantidade do item que está sendo trocado
  }) {
    setState(() {
      _swapPlanContext = {
        'item_refeicao_base_id': itemRefeicaoBaseId,
        if (alimentoOriginalId != null)
          'alimento_original_id': alimentoOriginalId,
        if (itemDiarioId != null) 'item_diario_id': itemDiarioId,
        if (quantidadeG != null) 'quantidade_g': quantidadeG,
      };
      _swapController.text = nomeParaBusca;
      _swapSearched = false;
      _swapResults = [];
      _swapError = '';
      _selectedIndex = 2;
    });
  }

  Future<void> _acceptSwapSuggestion(Map<String, dynamic> swap) async {
    final ctx = _swapPlanContext;
    // itemId=0 → item manual; itemId>0 → item do plano base (scan)
    // Ambos são válidos para troca com IA
    final rawId = ctx?['item_refeicao_base_id'];
    final itemId = rawId == null
        ? null
        : rawId is int
        ? rawId
        : int.tryParse(rawId.toString());
    if (itemId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um alimento na aba Início para trocar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final nome = swap['suggestion']?.toString().trim() ?? '';
    if (nome.isEmpty) return;

    final token = context.read<AppState>().token;
    if (token.isEmpty) return;

    setState(() => _swapAccepting = true);
    // quantidade_g do item original — passada no contexto para calcular porção correta
    final qtdOriginal = ctx?['quantidade_g']?.toString() ?? '100';
    final novoAlimento = <String, dynamic>{
      'Nome': nome,
      'quantidade_g': qtdOriginal, // servidor usa isso como porcao_g
      'porcao_g': qtdOriginal, // fator de escala = 1.0
      'calorias': '${swap['calories'] ?? 0}',
      'proteinas': '0',
      'carbos': '0',
      'gorduras': '0',
    };
    // Para itens manuais envia o id original para o servidor
    // saber qual linha de itens_diario atualizar
    final alimentoOriginalId = ctx?['alimento_original_id'];
    final itemDiarioId = ctx?['item_diario_id'];
    final result = await AiService.acceptFoodSwap(
      token: token,
      data: _todayIso(),
      itemRefeicaoBaseId: itemId,
      novoAlimento: novoAlimento,
      alimentoOriginalId: alimentoOriginalId,
      itemDiarioId: itemDiarioId,
    );
    if (!mounted) return;
    setState(() => _swapAccepting = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Troca registrada para hoje: $nome'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _swapPlanContext = null;
        _swapController.clear();
        _swapSearched = false;
        _swapResults = [];
        _swapError = '';
        _selectedIndex = 0;
      });
      await _loadDbPlan();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Falha ao registrar troca.',
          ),
          backgroundColor: Colors.red[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDbMealCard(Map ref, int index, Color green, Color greenLight) {
    final alimentos = (ref['alimentos'] as List?) ?? [];
    final totalCal = alimentos.fold<double>(0, (sum, a) {
      final m = Map<String, dynamic>.from(a as Map);
      return sum + _dbScaledValue(m, 'calorias');
    });

    final mealIcons = [
      Icons.wb_sunny_outlined,
      Icons.free_breakfast_outlined,
      Icons.lunch_dining_outlined,
      Icons.bakery_dining_outlined,
      Icons.dinner_dining_outlined,
      Icons.nightlight_round_outlined,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              mealIcons[index % mealIcons.length],
              color: green,
              size: 22,
            ),
          ),
          title: Text(
            ref['nome']?.toString() ?? 'Refeição',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              if ((ref['horario']?.toString() ?? '').isNotEmpty) ...[
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                Text(
                  ref['horario'].toString(),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
              Icon(
                Icons.local_fire_department,
                size: 12,
                color: Colors.orange[300],
              ),
              Text(
                '${totalCal.round()} kcal  •  ${alimentos.length} item(s)',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          iconColor: green,
          collapsedIconColor: Colors.grey[400],
          children: [
            // CORREÇÃO: botão + no topo da lista de alimentos
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final nomeDaRefeicao = ref['nome']?.toString();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LogMealScreen(initialMeal: nomeDaRefeicao),
                    ),
                  );
                  if (result != null &&
                      result is List<Map<String, dynamic>> &&
                      mounted) {
                    context.read<AppState>().addMeals(result);
                    setState(() {
                      _planLoading = true;
                      _dbPlan = null;
                    });
                    await _loadDbPlan();
                  }
                },
                icon: Icon(Icons.add, color: green, size: 16),
                label: Text(
                  'Adicionar alimento',
                  style: TextStyle(
                    color: green,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: green.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  minimumSize: const Size(double.infinity, 36),
                ),
              ),
            ),
            if (alimentos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Nenhum alimento cadastrado.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              )
            else
              ...alimentos.map<Widget>((al) {
                final alMap = Map<String, dynamic>.from(al as Map);
                final cal = _dbScaledValue(alMap, 'calorias');
                final prot = _dbScaledValue(alMap, 'proteinas');
                final carb = _dbScaledValue(alMap, 'carbos');
                final gord = _dbScaledValue(alMap, 'gorduras');
                final qtdFormatada = _formatQtd(alMap['quantidade_g']);
                final itemSlot = int.tryParse(
                  alMap['item_refeicao_base_id']?.toString() ?? '',
                );
                final trocaHoje = alMap['trocaDoDia'] == true;
                // Usa sempre o nome atual exibido (alMap['nome']),
                // não o original — após uma troca, o usuário quer substituir
                // o alimento que está vendo, não o que estava antes.
                final nomeBusca = alMap['nome']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F5),
                    borderRadius: BorderRadius.circular(12),
                    border: trocaHoje
                        ? Border.all(color: green.withValues(alpha: 0.45))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    alMap['nome']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (trocaHoje) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: greenLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Troca hoje',
                                      style: TextStyle(
                                        color: green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                if (alMap['adicionadoManualmente'] == true) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Adicionado',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            // MELHORIA: exibe macros no padrão da imagem de referência
                            Text(
                              'P: ${prot.toStringAsFixed(1)}g  •  C: ${carb.toStringAsFixed(1)}g  •  G: ${gord.toStringAsFixed(1)}g',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Coluna direita: kcal em destaque + peso formatado
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${cal.round()} kcal',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // MELHORIA: formatação dinâmica g / kg
                          Text(
                            qtdFormatada,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      // Ícone de troca horizontal (⇄) sempre visível e verde
                      // — itens do plano base: abre troca com IA
                      // — itens manuais (sem item_refeicao_base_id): ícone presente
                      //   mas sem ação de troca (não faz sentido trocar o que o
                      //   usuário já escolheu manualmente)
                      IconButton(
                        tooltip: 'Trocar com IA',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () => _openSwapFromPlan(
                          itemRefeicaoBaseId: itemSlot ?? 0,
                          nomeParaBusca: nomeBusca,
                          alimentoOriginalId: int.tryParse(
                            (alMap['alimento_original_id'] ?? alMap['id'])
                                    ?.toString() ??
                                '',
                          ),
                          itemDiarioId: int.tryParse(
                            alMap['item_diario_id']?.toString() ?? '',
                          ),
                          quantidadeG: alMap['quantidade_g'],
                        ),
                        icon: Icon(Icons.swap_horiz, color: green, size: 22),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaloriesCard(AppState state) {
    final percent = (state.caloriesConsumed / state.caloriesGoal).clamp(
      0.0,
      1.0,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calorias de Hoje',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${state.caloriesConsumed.toInt()} / ${state.caloriesGoal.toInt()} kcal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _calStat(
                'Consumidas',
                '${state.caloriesConsumed.toInt()}',
                Colors.greenAccent,
              ),
              _calStat(
                'Restantes',
                '${(state.caloriesGoal - state.caloriesConsumed).toInt()}',
                Colors.orangeAccent,
              ),
              _calStat('Meta', '${state.caloriesGoal.toInt()}', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosRow(AppState state) {
    return Row(
      children: [
        Expanded(
          child: _macroCard(
            'Proteínas',
            state.protein,
            state.proteinGoal,
            const Color(0xFF1565C0),
            Icons.fitness_center,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _macroCard(
            'Carboidratos',
            state.carbs,
            state.carbsGoal,
            const Color(0xFFE65100),
            Icons.grain,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _macroCard(
            'Gorduras',
            state.fat,
            state.fatGoal,
            const Color(0xFF6A1B9A),
            Icons.water_drop,
          ),
        ),
      ],
    );
  }

  Widget _macroCard(
    String label,
    double current,
    double goal,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            '${current.toInt()}g',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '/ ${goal.toInt()}g',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (current / goal).clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildWaterCard(AppState state) {
    final percent = (state.waterIntake / state.waterGoal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.water_drop,
                      color: Color(0xFF1565C0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Hidratação',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ],
              ),
              Text(
                '${state.waterIntake.toStringAsFixed(1)}L / ${state.waterGoal.toStringAsFixed(1)}L',
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1565C0),
              ),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(8, (i) {
              final cups = state.waterGoal / 8;
              final filled = state.waterIntake >= (i + 1) * cups;
              return GestureDetector(
                onTap: () {
                  context.read<AppState>().setWater(
                    ((i + 1) * cups).clamp(0.0, state.waterGoal),
                  );
                },
                child: Icon(
                  Icons.water_drop,
                  color: filled
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF1565C0).withValues(alpha: 0.15),
                  size: 26,
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Toque nas gotas para registrar',
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSection(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Refeições de Hoje',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2B1C),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  // Sem contexto de refeição específica — mostra seletor normalmente
                  MaterialPageRoute(builder: (_) => const LogMealScreen()),
                );
                if (result != null && result is List<Map<String, dynamic>>) {
                  context.read<AppState>().addMeals(result);
                }
              },
              icon: const Icon(Icons.add, size: 16, color: Color(0xFF2E7D32)),
              label: const Text(
                'Registrar',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (state.meals.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.restaurant, color: Colors.grey[300], size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhuma refeição registrada hoje',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ...state.meals.asMap().entries.map((entry) {
          final i = entry.key;
          final meal = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            meal['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF1B2B1C),
                            ),
                          ),
                          Text(
                            meal['meal'] ?? '',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${meal['unit']}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${meal['cal']} kcal',
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                  onPressed: () => context.read<AppState>().removeMeal(i),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================
  // FUGAS
  // ==========================================
  Widget _buildFugasPage() => const DietEscapeScreen();

  Future<void> _searchSwap() async {
    final food = _swapController.text.trim();
    if (food.isEmpty) return;
    final state = context.read<AppState>();
    setState(() {
      _swapLoading = true;
      _swapError = '';
      _swapResults = [];
      _swapSearched = true;
    });
    final results = await AiService.suggestFoodSwap(
      foodName: food,
      goal: state.goal,
      allergies: state.allergies.toList(),
      preferences: state.preferences.toList(),
      token: state.token,
    );
    if (!mounted) return;
    setState(() {
      _swapLoading = false;
      _swapResults = results;
      if (results.isEmpty) {
        _swapError = 'Nenhuma sugestão encontrada. Tente outro alimento.';
      }
    });
  }

  Widget _buildTrocasPage() {
    const green = Color(0xFF2E7D32);
    const greenLight = Color(0xFFE8F5E9);

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                        Icons.swap_horiz,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trocar Alimento',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Substitutos inteligentes com IA',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                          controller: _swapController,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _searchSwap(),
                          decoration: const InputDecoration(
                            hintText: 'Ex: Arroz branco, Frango, Leite...',
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
                        onTap: _swapLoading ? null : _searchSwap,
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
                          child: _swapLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Buscar',
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

          if (_swapPlanContext != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Material(
                color: greenLight,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available, color: green, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Item do plano selecionado. Aceitar uma sugestão grava a troca só para ${_todayIso()}.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            height: 1.35,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancelar seleção',
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey[700],
                          size: 22,
                        ),
                        onPressed: () =>
                            setState(() => _swapPlanContext = null),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Expanded(
            child: _swapLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: green),
                        const SizedBox(height: 16),
                        Text(
                          'Consultando a IA...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : !_swapSearched
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: greenLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.swap_horiz,
                              size: 48,
                              color: green,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Substitua qualquer alimento',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Digite um alimento acima e a IA sugerirá 3 alternativas nutricionalmente equivalentes, '
                            'respeitando suas alergias e preferências. Para salvar no seu plano do dia, '
                            'use o ícone de troca (⇅) ao lado de um alimento na aba Início e depois aceite uma sugestão aqui.',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : _swapError.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _swapError,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _searchSwap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: green,
                            ),
                            child: const Text(
                              'Tentar novamente',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: greenLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: green,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Substitutos para: '),
                                    TextSpan(
                                      text: _swapController.text.trim(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._swapResults.asMap().entries.map((entry) {
                        final i = entry.key;
                        final swap = entry.value;
                        final icons = [
                          Icons.eco,
                          Icons.grain,
                          Icons.local_dining,
                        ];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: greenLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        icons[i % icons.length],
                                        color: green,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            swap['suggestion']?.toString() ??
                                                '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            swap['reason']?.toString() ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              if (swap['ratio'] != null)
                                                _swapChip(
                                                  Icons.swap_horiz,
                                                  swap['ratio'].toString(),
                                                  Colors.blue[50]!,
                                                  Colors.blue[700]!,
                                                ),
                                              const SizedBox(width: 8),
                                              if (swap['calories'] != null)
                                                _swapChip(
                                                  Icons.local_fire_department,
                                                  '${swap['calories']} kcal',
                                                  Colors.orange[50]!,
                                                  Colors.orange[700]!,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_swapPlanContext != null) ...[
                                  const SizedBox(height: 14),
                                  ElevatedButton(
                                    onPressed: _swapAccepting
                                        ? null
                                        : () => _acceptSwapSuggestion(
                                            Map<String, dynamic>.from(swap),
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _swapAccepting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Aceitar e registrar para hoje',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          _swapController.clear();
                          setState(() {
                            _swapPlanContext = null;
                            _swapSearched = false;
                            _swapResults = [];
                            _swapError = '';
                          });
                        },
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Nova busca'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: green,
                          side: const BorderSide(color: green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _swapChip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PERFIL
  // ==========================================

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _curPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _cfmPassCtrl = TextEditingController();
  bool _savingInfo = false;
  bool _savingPass = false;
  bool _editingInfo = false;
  bool _editingPass = false;

  void _initPerfilControllers() {
    final s = context.read<AppState>();
    _nameCtrl.text = s.userName;
    _emailCtrl.text = s.userEmail;
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    if (!mounted) return;
    context.read<AppState>().setPhoto(base64Encode(bytes));
    setState(() {});
  }

  Future<void> _saveInfo() async {
    final nome = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (nome.isEmpty || email.isEmpty) {
      _showSnack('Preencha nome e e-mail.', error: true);
      return;
    }
    setState(() => _savingInfo = true);
    final res = await ApiService.updateProfile(
      token: context.read<AppState>().token,
      nome: nome,
      email: email,
    );
    if (!mounted) return;
    setState(() {
      _savingInfo = false;
      _editingInfo = false;
    });
    if (res['success'] == true) {
      await context.read<AppState>().setUser(nome, email);
      _showSnack('Dados atualizados com sucesso!');
    } else {
      _showSnack(res['message'] ?? 'Erro ao atualizar.', error: true);
    }
  }

  Future<void> _savePassword() async {
    final cur = _curPassCtrl.text.trim();
    final nov = _newPassCtrl.text.trim();
    final cfm = _cfmPassCtrl.text.trim();
    if (cur.isEmpty || nov.isEmpty || cfm.isEmpty) {
      _showSnack('Preencha todos os campos.', error: true);
      return;
    }
    if (nov != cfm) {
      _showSnack('As senhas nao coincidem.', error: true);
      return;
    }
    if (nov.length < 6) {
      _showSnack('Minimo 6 caracteres.', error: true);
      return;
    }
    setState(() => _savingPass = true);
    final res = await ApiService.changePassword(
      token: context.read<AppState>().token,
      currentPassword: cur,
      newPassword: nov,
    );
    if (!mounted) return;
    setState(() {
      _savingPass = false;
      _editingPass = false;
    });
    if (res['success'] == true) {
      _curPassCtrl.clear();
      _newPassCtrl.clear();
      _cfmPassCtrl.clear();
      _showSnack('Senha alterada com sucesso!');
    } else {
      _showSnack(res['message'] ?? 'Erro ao alterar senha.', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error
            ? const Color(0xFFD32F2F)
            : const Color(0xFF388E3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildPerfilPage() {
    final state = context.watch<AppState>();
    final photo = state.photoBase64;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header com gradiente
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFF388E3C),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white24,
                              backgroundImage: photo != null
                                  ? MemoryImage(base64Decode(photo))
                                  : null,
                              child: photo == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Color(0xFF2E7D32),
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.userName.isNotEmpty ? state.userName : 'Usuario',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.userEmail.isNotEmpty
                          ? state.userEmail
                          : 'email@exemplo.com',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white70,
                        size: 16,
                      ),
                      label: const Text(
                        'Mudar foto',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Dados pessoais
                    _perfilCard(
                      title: 'Dados Pessoais',
                      icon: Icons.person_outline,
                      trailing: TextButton(
                        onPressed: () {
                          if (!_editingInfo) _initPerfilControllers();
                          setState(() => _editingInfo = !_editingInfo);
                        },
                        child: Text(
                          _editingInfo ? 'Cancelar' : 'Editar',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: _editingInfo
                          ? Column(
                              children: [
                                _perfilField(
                                  _nameCtrl,
                                  'Nome completo',
                                  Icons.person_outline,
                                ),
                                const SizedBox(height: 12),
                                _perfilField(
                                  _emailCtrl,
                                  'E-mail',
                                  Icons.email_outlined,
                                  keyboard: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _savingInfo ? null : _saveInfo,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _savingInfo
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Salvar alteracoes',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _profileTile(
                                  Icons.person_outline,
                                  'Nome',
                                  state.userName,
                                ),
                                _profileTile(
                                  Icons.email_outlined,
                                  'E-mail',
                                  state.userEmail,
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Seguranca
                    _perfilCard(
                      title: 'Seguranca',
                      icon: Icons.lock_outline,
                      trailing: TextButton(
                        onPressed: () => setState(() {
                          _editingPass = !_editingPass;
                          if (!_editingPass) {
                            _curPassCtrl.clear();
                            _newPassCtrl.clear();
                            _cfmPassCtrl.clear();
                          }
                        }),
                        child: Text(
                          _editingPass ? 'Cancelar' : 'Alterar',
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: _editingPass
                          ? Column(
                              children: [
                                _perfilField(
                                  _curPassCtrl,
                                  'Senha atual',
                                  Icons.lock_outline,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 12),
                                _perfilField(
                                  _newPassCtrl,
                                  'Nova senha',
                                  Icons.lock_reset_outlined,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 12),
                                _perfilField(
                                  _cfmPassCtrl,
                                  'Confirmar nova senha',
                                  Icons.lock_reset_outlined,
                                  isPassword: true,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: _savingPass
                                        ? null
                                        : _savePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B5E20),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _savingPass
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'Confirmar alteracao',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            )
                          : _profileTile(
                              Icons.lock_outline,
                              'Senha',
                              '...........',
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Plano alimentar
                    _perfilCard(
                      title: 'Plano Alimentar',
                      icon: Icons.restaurant_menu_outlined,
                      child: !state.hasPlan
                          ? Column(
                              children: [
                                const Icon(
                                  Icons.add_chart_outlined,
                                  size: 40,
                                  color: Color(0xFF2E7D32),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Nenhum plano criado ainda.',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Crie seu plano para acompanhar seus macros.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _macroRow(
                                  'Objetivo',
                                  state.goal,
                                  Icons.flag_outlined,
                                ),
                                _macroRow(
                                  'Peso',
                                  '${state.weight.toStringAsFixed(1)} kg',
                                  Icons.monitor_weight_outlined,
                                ),
                                _macroRow(
                                  'Altura',
                                  '${state.height.toStringAsFixed(0)} cm',
                                  Icons.height,
                                ),
                                _macroRow(
                                  'Idade',
                                  '${state.age} anos',
                                  Icons.cake_outlined,
                                ),
                                _macroRow(
                                  'Atividade',
                                  state.activityLevel,
                                  Icons.directions_run,
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    _macroChip(
                                      'Calorias',
                                      '${state.caloriesGoal.toInt()} kcal',
                                      Icons.local_fire_department_outlined,
                                      const Color(0xFFE53935),
                                    ),
                                    const SizedBox(width: 8),
                                    _macroChip(
                                      'Proteina',
                                      '${state.proteinGoal.toInt()}g',
                                      Icons.egg_outlined,
                                      const Color(0xFF1565C0),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _macroChip(
                                      'Carbs',
                                      '${state.carbsGoal.toInt()}g',
                                      Icons.grain_outlined,
                                      const Color(0xFFF57C00),
                                    ),
                                    const SizedBox(width: 8),
                                    _macroChip(
                                      'Gorduras',
                                      '${state.fatGoal.toInt()}g',
                                      Icons.opacity_outlined,
                                      const Color(0xFF6A1B9A),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _macroRow(
                                  'Meta de Agua',
                                  '${state.waterGoal.toStringAsFixed(1)} L/dia',
                                  Icons.water_drop_outlined,
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScanPlanScreen(),
                              ),
                            ).then((_) {
                              setState(() {
                                _planLoading = true;
                                _dbPlan = null;
                              });
                              _loadDbPlan();
                            }),
                        icon: const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Scan do plano alimentar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Sair da conta',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perfilCard({
    required String title,
    required Widget child,
    Widget? trailing,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _perfilField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return _PerfilTextField(
      controller: ctrl,
      label: label,
      icon: icon,
      isPassword: isPassword,
      keyboard: keyboard,
    );
  }

  Widget _macroRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(String title, IconData icon) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: const Color(0xFF2E7D32)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Em breve...',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fastfood_rounded),
            label: 'Fugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Trocas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _PerfilTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboard;
  const _PerfilTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.isPassword = false,
    this.keyboard = TextInputType.text,
  });
  @override
  State<_PerfilTextField> createState() => _PerfilTextFieldState();
}

class _PerfilTextFieldState extends State<_PerfilTextField> {
  bool _obscure = true;
  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: widget.keyboard,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, color: const Color(0xFF2E7D32)),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }
}
