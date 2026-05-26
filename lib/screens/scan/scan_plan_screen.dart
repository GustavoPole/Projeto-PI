import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:projeto_pi/providers/app_state.dart';

class ScanPlanScreen extends StatefulWidget {
  const ScanPlanScreen({super.key});

  @override
  State<ScanPlanScreen> createState() => _ScanPlanScreenState();
}

class _ScanPlanScreenState extends State<ScanPlanScreen> {
  static const _green = Color(0xFF2E7D32);
  static const _greenLight = Color(0xFFE8F5E9);

  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.3.2:3000';
    return 'http://localhost:3000';
  }

  PlatformFile? _file;
  bool _analyzing = false;
  bool _saving = false;
  Map<String, dynamic>? _data;
  String _error = '';
  bool _savedOk = false;

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _file = result.files.first;
          _data = null;
          _error = '';
          _savedOk = false;
        });
      }
    } catch (e) {
      setState(() => _error = 'Erro ao selecionar arquivo: $e');
    }
  }

  Future<void> _analyze() async {
    if (_file == null || _file!.bytes == null) return;
    final token = context.read<AppState>().token;

    setState(() {
      _analyzing = true;
      _error = '';
      _data = null;
    });

    try {
      final base64File = base64Encode(_file!.bytes!);
      final mime = _mimeType(_file!.extension ?? 'jpg');

      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/scan-plan'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'fileBase64': base64File, 'mimeType': mime}),
          )
          .timeout(const Duration(seconds: 90));

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body['success'] == true) {
        setState(() => _data = Map<String, dynamic>.from(body['data']));
      } else {
        setState(() => _error = body['message'] ?? 'Erro ao analisar o arquivo.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _save() async {
    if (_data == null) return;
    final token = context.read<AppState>().token;

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final res = await http
          .post(
            Uri.parse('$_baseUrl/api/save-scanned-plan'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': _data}),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body['success'] == true) {
        setState(() => _savedOk = true);
      } else {
        setState(() => _error = body['message'] ?? 'Erro ao salvar no banco.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro de conexão: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _savedOk ? _buildSuccess() : _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digitalizar Plano',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              Text(
                'Análise inteligente com Gemini',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: _green, size: 64),
          ),
          const SizedBox(height: 24),
          const Text(
            'Plano salvo com sucesso!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'O plano alimentar foi cadastrado no banco de dados e está ativo.',
            style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.home_rounded, color: Colors.white),
              label: const Text('Voltar ao perfil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // selecionar arquivo
        _stepCard(
          step: '1',
          title: 'Selecione o arquivo',
          subtitle: 'JPEG, PNG ou PDF do plano alimentar',
          child: _buildFilePicker(),
        ),

        const SizedBox(height: 16),

        // analisar
        _stepCard(
          step: '2',
          title: 'Analisar com IA',
          subtitle: 'O Gemini extrai refeições, alimentos e macros',
          child: _buildAnalyzeSection(),
        ),

        //preview e salvar 
        if (_data != null) ...[
          const SizedBox(height: 16),
          _stepCard(
            step: '3',
            title: 'Plano extraído — revise e salve',
            subtitle: 'Confirme os dados antes de gravar no banco',
            child: _buildPreviewSection(),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: (_analyzing || _saving) ? null : _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  _file != null ? Icons.insert_drive_file_rounded : Icons.upload_file_rounded,
                  size: 44,
                  color: _green,
                ),
                const SizedBox(height: 10),
                Text(
                  _file != null ? _file!.name : 'Toque para selecionar',
                  style: TextStyle(
                    color: _file != null ? Colors.black87 : Colors.grey[500],
                    fontWeight: _file != null ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_file != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${(_file!.size / 1024).toStringAsFixed(1)} KB  •  ${_file!.extension?.toUpperCase()}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                if (_file == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'JPG  •  PNG  •  PDF',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_file != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: (_analyzing || _saving) ? null : _pickFile,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Trocar arquivo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: _green),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeSection() {
    return Column(
      children: [
        if (_error.isNotEmpty) _errorBox(_error),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_file == null || _analyzing || _saving) ? null : _analyze,
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(
              _analyzing ? 'Analisando...' : 'Analisar com IA',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        if (_analyzing) ...[
          const SizedBox(height: 10),
          Text(
            'Aguarde — isso pode levar até 30 segundos...',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Map<String, num> _calcTotais(List refeicoes) {
    double cal = 0, prot = 0, carb = 0, gord = 0;
    for (final r in refeicoes) {
      for (final al in (r['alimentos'] as List? ?? [])) {
        final qtd = (al['quantidade_g'] as num?)?.toDouble() ?? 100.0;
        final porc = double.tryParse(al['porcao_g']?.toString() ?? '100') ?? 100.0;
        final factor = porc > 0 ? qtd / porc : 1.0;
        cal  += (double.tryParse(al['calorias']?.toString()  ?? '0') ?? 0) * factor;
        prot += (double.tryParse(al['proteinas']?.toString() ?? '0') ?? 0) * factor;
        carb += (double.tryParse(al['carbos']?.toString()    ?? '0') ?? 0) * factor;
        gord += (double.tryParse(al['gorduras']?.toString()  ?? '0') ?? 0) * factor;
      }
    }
    return {
      'calorias': cal.round(),
      'proteinas': (prot * 10).round() / 10,
      'carbos': (carb * 10).round() / 10,
      'gordura': (gord * 10).round() / 10,
    };
  }

  Widget _buildPreviewSection() {
    final plan = _data!['plano'] as Map?;
    final mm = _data!['max_micronutrientes'] as Map?;
    final refeicoes = (_data!['refeicoes'] as List?) ?? [];
    final totalAlimentos = refeicoes.fold<int>(
      0,
      (sum, r) => sum + ((r['alimentos'] as List?)?.length ?? 0),
    );

    final allZero = mm == null ||
        ((mm['calorias'] ?? 0) == 0 &&
         (mm['proteinas'] ?? 0) == 0 &&
         (mm['carbos'] ?? 0) == 0 &&
         (mm['gordura'] ?? 0) == 0);
    final macros = allZero ? _calcTotais(refeicoes) : mm!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Resumo do plano
        _infoRow(Icons.assignment_outlined, 'Plano', plan?['nome'] ?? '-'),
        _infoRow(Icons.restaurant_menu, 'Refeições', '${refeicoes.length}'),
        _infoRow(Icons.fastfood, 'Alimentos', '$totalAlimentos itens'),
        const SizedBox(height: 10),
        _macroRow(macros),

        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),

        // Lista de refeições
        const Text(
          'Refeições extraídas',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 10),
        ...refeicoes.map((r) => _refeicaoCard(r)),

        const SizedBox(height: 16),

        // Botão salvar
        if (_error.isNotEmpty) ...[
          _errorBox(_error),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_alt, color: Colors.white),
            label: Text(
              _saving ? 'Salvando...' : 'Salvar no banco de dados',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepCard({
    required String step,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                child: Center(
                  child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _macroRow(Map mm) {
    return Row(
      children: [
        _macroChip('Calorias', '${mm['calorias'] ?? 0}', Colors.orange[50]!, Colors.orange[800]!),
        const SizedBox(width: 6),
        _macroChip('Proteínas', '${mm['proteinas'] ?? 0}g', Colors.blue[50]!, Colors.blue[800]!),
        const SizedBox(width: 6),
        _macroChip('Carbos', '${mm['carbos'] ?? 0}g', Colors.purple[50]!, Colors.purple[800]!),
        const SizedBox(width: 6),
        _macroChip('Gordura', '${mm['gordura'] ?? 0}g', Colors.red[50]!, Colors.red[800]!),
      ],
    );
  }

  Widget _macroChip(String label, String value, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _refeicaoCard(dynamic ref) {
    final alimentos = (ref['alimentos'] as List?) ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        leading: const Icon(Icons.restaurant_rounded, color: _green, size: 20),
        title: Text(
          ref['nome'] ?? 'Refeição',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Text(
              ref['horario_previsto'] ?? '',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              '${alimentos.length} item(s)',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        children: alimentos.map<Widget>((al) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${al['Nome'] ?? ''}  —  ${al['quantidade_g']}g',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Prot: ${al['proteinas']}g  •  Carb: ${al['carbos']}g  •  Gord: ${al['gorduras']}g',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${al['calorias']} kcal',
                    style: TextStyle(color: Colors.orange[800], fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
        ],
      ),
    );
  }
}
