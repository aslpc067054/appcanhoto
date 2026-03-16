import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math; // <<< NOVO: para minWidth do grid

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:appcanhoto/core/api_config.dart';

/// =======================================
/// MODELOS
/// =======================================

class Empresa {
  final int id;
  final String nomeFantasia;
  final int status;
  Empresa({required this.id, required this.nomeFantasia, required this.status});

  factory Empresa.fromJson(Map<String, dynamic> j) => Empresa(
        id: (j['Id'] ?? j['id']) as int,
        nomeFantasia: (j['NomeFantasia'] ?? j['nomeFantasia'] ?? '') as String,
        status: (j['Status'] ?? j['status'] ?? 0) as int,
      );
}

/// ATENÇÃO: ajustado para o contrato do UsuariosController
/// GET /api/usuarios -> [{ Id, Usuario, NomeCompleto }]
class Usuario {
  final int id;
  final String usuario;       // campo "Usuario" do backend
  final String? nomeCompleto; // campo "NomeCompleto" do backend
  Usuario({required this.id, required this.usuario, this.nomeCompleto});

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: (j['Id'] ?? j['id']) as int,
        usuario: (j['Usuario'] ?? j['usuario'] ?? '') as String,
        nomeCompleto: (j['NomeCompleto'] ?? j['nomeCompleto']) as String?,
      );
}

/// Item retornado pelo relatório (sem imagem completa)
class CanhotoRow {
  final int id;
  final int idEmpresa;
  final String empresaNome;
  final String numeroNota;
  final DateTime dataHora;
  final Uint8List? thumbnail; // ThumbnailBase64 -> bytes

  CanhotoRow({
    required this.id,
    required this.idEmpresa,
    required this.empresaNome,
    required this.numeroNota,
    required this.dataHora,
    required this.thumbnail,
  });

  factory CanhotoRow.fromJson(Map<String, dynamic> j) => CanhotoRow(
        id: (j['Id'] ?? j['id']) as int,
        idEmpresa: (j['IdEmpresa'] ?? j['idEmpresa']) as int,
        empresaNome: (j['EmpresaNome'] ?? j['empresaNome'] ?? '') as String,
        numeroNota: (j['NumeroNota'] ?? j['numeroNota'] ?? '') as String,
        dataHora: DateTime.parse((j['DataHora'] ?? j['dataHora']) as String),
        thumbnail: (j['ThumbnailBase64'] != null && (j['ThumbnailBase64'] as String).isNotEmpty)
            ? base64Decode(j['ThumbnailBase64'] as String)
            : null,
      );
}

/// =======================================
/// PÁGINA
/// =======================================

class RelatorioPage extends StatefulWidget {
  final String usuarioLogado; // mostrado no AppBar
  const RelatorioPage({super.key, required this.usuarioLogado});

  @override
  State<RelatorioPage> createState() => _RelatorioPageState();
}

class _RelatorioPageState extends State<RelatorioPage> {
  String get baseUrl => '${ApiConfig.base}/api';

  Map<String, String> get _headers => const {
        'Accept': 'application/json',
      };

  // Filtros
  final _empresaCtrl = TextEditingController();
  final _usuarioCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _dataIniCtrl = TextEditingController();
  final _dataFimCtrl = TextEditingController();

  Empresa? _empresaSel;
  Usuario? _usuarioSel;
  DateTime? _dataIni;
  DateTime? _dataFim;

  // Focus para fechar autocomplete
  FocusNode? _empresaFocusNode;
  FocusNode? _usuarioFocusNode;

  // Listas
  List<Empresa> _empresas = [];
  List<Usuario> _usuarios = [];

  // Resultados
  List<CanhotoRow> _resultados = [];
  bool _buscando = false;
  int _page = 1;
  int _pageSize = 20;
  int _total = 0;

  final _df = DateFormat('dd/MM/yyyy HH:mm');

  // <<< NOVO: controlador da barra de rolagem HORIZONTAL do grid
  final ScrollController _hTableCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _carregarEmpresas();
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _usuarioCtrl.dispose();
    _notaCtrl.dispose();
    _dataIniCtrl.dispose();
    _dataFimCtrl.dispose();

    // <<< NOVO: dispose do controller horizontal
    _hTableCtrl.dispose();

    super.dispose();
  }

  // =========================
  // CARREGAMENTO
  // =========================

  Future<void> _carregarEmpresas() async {
    try {
      final uri = Uri.parse('$baseUrl/empresas');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data is List) ? data : (data['data'] ?? []);
        _empresas = List<Map<String, dynamic>>.from(list).map(Empresa.fromJson).toList()
          ..sort((a, b) => a.nomeFantasia.compareTo(b.nomeFantasia));
      } else {
        _showSnack('Erro ao carregar empresas (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Falha ao carregar empresas. Verifique a API/CORS.');
    } finally {
      if (mounted) setState(() {});
    }
  }

  /// ATENÇÃO: mapeia para { Id, Usuario, NomeCompleto }
  Future<void> _carregarUsuarios() async {
    try {
      final uri = Uri.parse('$baseUrl/usuarios');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data is List) ? data : (data['data'] ?? []);
        _usuarios = List<Map<String, dynamic>>.from(list).map(Usuario.fromJson).toList()
          ..sort((a, b) => (a.nomeCompleto ?? a.usuario).compareTo(b.nomeCompleto ?? b.usuario));
      } else {
        _showSnack('Erro ao carregar usuários (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Falha ao carregar usuários. Verifique a API/CORS.');
    } finally {
      if (mounted) setState(() {});
    }
  }

  // =========================
  // BUSCA (RELATÓRIO)
  // =========================

  Future<void> _buscar({int? toPage}) async {
    setState(() => _buscando = true);
    try {
      final page = toPage ?? _page;
      final params = <String, String>{
        'Page': '$page',
        'PageSize': '$_pageSize',
        'WithThumb': 'false', // service atual não gera thumb; preview fica placeholder
      };
      if (_empresaSel != null) params['IdEmpresa'] = '${_empresaSel!.id}';
      if (_usuarioSel != null) params['IdUsuario'] = '${_usuarioSel!.id}';
      if (_notaCtrl.text.trim().isNotEmpty) params['NumeroNota'] = _notaCtrl.text.trim();

      // <<< AJUSTE FUSO: somar 3 horas nas datas enviadas à API
      final dataInicioApi = _dataIni?.add(const Duration(hours: 3));
      final dataFimApi = _dataFim?.add(const Duration(hours: 3));
      if (dataInicioApi != null) params['DataHoraIni'] = dataInicioApi.toIso8601String();
      if (dataFimApi != null) params['DataHoraFim'] = dataFimApi.toIso8601String();

      final uri = Uri.parse('$baseUrl/canhotos/relatorio').replace(queryParameters: params);
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 45));
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final List list = (j['Data'] ?? j['data'] ?? []) as List;
        _resultados = list.map((e) => CanhotoRow.fromJson(Map<String, dynamic>.from(e))).toList();
        _page = (j['Page'] ?? j['page'] ?? page) as int;
        _pageSize = (j['PageSize'] ?? j['pageSize'] ?? _pageSize) as int;
        _total = (j['Total'] ?? j['total'] ?? _resultados.length) as int;
      } else {
        _showSnack('Erro na consulta (${resp.statusCode}).');
      }
    } catch (e) {
      _showSnack('Falha ao consultar relatório. Verifique API/CORS.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _limpar() {
    _empresaSel = null;
    _usuarioSel = null;
    _empresaCtrl.clear();
    _usuarioCtrl.clear();
    _notaCtrl.clear();
    _dataIni = null;
    _dataFim = null;
    _dataIniCtrl.clear();
    _dataFimCtrl.clear();
    _resultados.clear();
    _page = 1;
    _total = 0;
    setState(() {});
  }

  // =========================
  // DATE/TIME pickers
  // =========================

  Future<void> _pickDateTime({required bool isInicio}) async {
    final initial = isInicio ? (_dataIni ?? DateTime.now()) : (_dataFim ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx!).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (isInicio) {
      _dataIni = dt;
      _dataIniCtrl.text = _df.format(dt);
    } else {
      _dataFim = dt;
      _dataFimCtrl.text = _df.format(dt);
    }
    setState(() {});
  }

  // =========================
  // VISUALIZAR / BAIXAR
  // =========================

  Future<Uint8List?> _carregarImagemCompleta(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/canhotos/$id/imagem');
      final resp = await http.get(uri).timeout(const Duration(seconds: 45));
      if (resp.statusCode == 200) {
        final ct = resp.headers['content-type'] ?? '';
        if (ct.startsWith('image/')) return resp.bodyBytes;
        try {
          final j = jsonDecode(utf8.decode(resp.bodyBytes));
          if (j['ImagemBase64'] != null) return base64Decode(j['ImagemBase64']);
          if (j['imagemBase64'] != null) return base64Decode(j['imagemBase64']);
        } catch (_) {}
      }
    } catch (_) {}
    _showSnack('Não foi possível carregar a imagem.');
    return null;
  }

  Future<void> _visualizar(CanhotoRow row) async {
    final bytes = await _carregarImagemCompleta(row.id);
    if (bytes == null) return;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.05)),
                child: Row(
                  children: [
                    Expanded(child: Text('Canhoto #${row.id} — ${row.empresaNome} • NF ${row.numeroNota}')),
                    IconButton(
                      tooltip: 'Baixar',
                      onPressed: () => _baixar(row.id),
                      icon: const Icon(Icons.download),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(child: InteractiveViewer(child: Center(child: Image.memory(bytes, fit: BoxFit.contain)))),
            ],
          ),
        ),
      ),
    );
  }

  // Future<void> _baixar(int id) async {
  //   final uri = Uri.parse('$baseUrl/canhotos/$id/imagem?download=true');
  //   if (await canLaunchUrl(uri)) {
  //     await launchUrl(uri, mode: LaunchMode.externalApplication);
  //   } else {
  //     _showSnack('Não foi possível abrir o link para download.');
  //   }
  // }

Future<void> _baixar(int id) async {
  final uri = Uri.parse('$baseUrl/canhotos/$id/imagem?download=true');

  try {
    // 1) Tente abrir externamente (navegador)
    final okExternal = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (okExternal) return;

    // 2) Fallback: tente abrir em um webview in-app (se um browser externo falhar)
    final okInApp = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (okInApp) return;

    // 3) Último recurso: tente o modo padrão da plataforma
    final okDefault = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (okDefault) return;

    _showSnack('Não foi possível abrir o link para download.');
  } catch (e) {
    // Logue o erro para diagnosticar (ex.: via Firebase Crashlytics ou print no debug)
    // ignore: avoid_print
    print('Falha ao abrir download ($uri): $e');

    _showSnack('Não foi possível abrir o link para download.');
  }
}



  // =========================
  // UI
  // =========================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalPages = (_total / _pageSize).ceil().clamp(1, 999999);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de Canhotos'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text(widget.usuarioLogado, style: const TextStyle(fontWeight: FontWeight.w600))),
          )
        ],
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== FILTROS =====
          Card(
            color: isDark ? const Color(0xFF121212) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Linha 1 — Empresa | Usuário
                  Row(
                    children: [
                      Expanded(
                        child: Autocomplete<Empresa>(
                          displayStringForOption: (e) => e.nomeFantasia,
                          optionsBuilder: (TextEditingValue t) {
                            if (t.text.isEmpty) return _empresas;
                            final txt = t.text.toLowerCase();
                            return _empresas.where((e) => e.nomeFantasia.toLowerCase().contains(txt));
                          },
                          fieldViewBuilder: (ctx, controller, focus, _) {
                            _empresaFocusNode = focus;
                            controller.text = _empresaCtrl.text;
                            controller.selection = _empresaCtrl.selection;
                            controller.addListener(() => _empresaCtrl.value = controller.value);
                            return TextField(
                              controller: controller,
                              focusNode: focus,
                              decoration: const InputDecoration(
                                labelText: 'Empresa',
                                prefixIcon: Icon(Icons.apartment),
                              ),
                            );
                          },
                          onSelected: (e) {
                            _empresaSel = e;
                            _empresaCtrl.text = e.nomeFantasia;
                            _empresaFocusNode?.unfocus(); // fecha listbox
                            setState(() {});
                          },
                          optionsViewBuilder: (ctx, onSelected, options) => Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              child: SizedBox(
                                height: 240,
                                child: ListView.builder(
                                  itemCount: options.length,
                                  itemBuilder: (_, i) {
                                    final e = options.elementAt(i);
                                    return ListTile(
                                      title: Text(e.nomeFantasia),
                                      onTap: () {
                                        onSelected(e);
                                        FocusScope.of(ctx).unfocus();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Autocomplete<Usuario>(
                          displayStringForOption: (u) => u.nomeCompleto?.isNotEmpty == true ? u.nomeCompleto! : u.usuario,
                          optionsBuilder: (TextEditingValue t) {
                            if (t.text.isEmpty) return _usuarios;
                            final txt = t.text.toLowerCase();
                            return _usuarios.where((u) =>
                                (u.nomeCompleto ?? '').toLowerCase().contains(txt) ||
                                u.usuario.toLowerCase().contains(txt));
                          },
                          fieldViewBuilder: (ctx, controller, focus, _) {
                            _usuarioFocusNode = focus;
                            controller.text = _usuarioCtrl.text;
                            controller.selection = _usuarioCtrl.selection;
                            controller.addListener(() => _usuarioCtrl.value = controller.value);
                            return TextField(
                              controller: controller,
                              focusNode: focus,
                              decoration: const InputDecoration(
                                labelText: 'Usuário',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            );
                          },
                          onSelected: (u) {
                            _usuarioSel = u;
                            _usuarioCtrl.text = u.nomeCompleto?.isNotEmpty == true ? u.nomeCompleto! : u.usuario;
                            _usuarioFocusNode?.unfocus();
                            setState(() {});
                          },
                          optionsViewBuilder: (ctx, onSelected, options) => Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              child: SizedBox(
                                height: 240,
                                child: ListView.builder(
                                  itemCount: options.length,
                                  itemBuilder: (_, i) {
                                    final u = options.elementAt(i);
                                    return ListTile(
                                      title: Text(u.nomeCompleto?.isNotEmpty == true ? u.nomeCompleto! : u.usuario),
                                      onTap: () {
                                        onSelected(u);
                                        FocusScope.of(ctx).unfocus();
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Linha 2 — Nota | Início | Fim
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _notaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nº Nota Fiscal',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dataIniCtrl,
                          readOnly: true,
                          onTap: () => _pickDateTime(isInicio: true),
                          decoration: const InputDecoration(
                            labelText: 'Início (data/hora)',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dataFimCtrl,
                          readOnly: true,
                          onTap: () => _pickDateTime(isInicio: false),
                          decoration: const InputDecoration(
                            labelText: 'Fim (data/hora)',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _buscando ? null : () => _buscar(toPage: 1),
                          icon: _buscando
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _buscando ? null : _limpar,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ===== RESULTADOS =====
          Card(
            color: isDark ? const Color(0xFF121212) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _resultados.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Nenhum registro encontrado.')),
                        )
                      : Column(
                          children: [
                            // >>> ALTERADO: barra de rolagem horizontal + largura mínima forçada
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final double minTableWidth = math.max(constraints.maxWidth, 1100); // ajuste se quiser
                                return Scrollbar(
                                  controller: _hTableCtrl,
                                  thumbVisibility: true,
                                  notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
                                  child: SingleChildScrollView(
                                    controller: _hTableCtrl,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: minTableWidth),
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Preview')),
                                          DataColumn(label: Text('Empresa')),
                                          DataColumn(label: Text('NF')),
                                          DataColumn(label: Text('Data/Hora')),
                                          DataColumn(label: Text('Ações')),
                                        ],
                                        rows: _resultados.map((r) {
                                          // <<< AJUSTE FUSO: subtrair 3 horas para exibição
                                          final exibicao = r.dataHora.subtract(const Duration(hours: 3));
                                          final dt = _df.format(exibicao);

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                SizedBox(
                                                  width: 90,
                                                  height: 70,
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: r.thumbnail == null || r.thumbnail!.isEmpty
                                                        ? Container(
                                                            color: Colors.black12,
                                                            child: const Icon(Icons.image_not_supported, size: 28),
                                                          )
                                                        : Image.memory(r.thumbnail!, fit: BoxFit.cover),
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(r.empresaNome)),
                                              DataCell(Text(r.numeroNota)),
                                              DataCell(Text(dt)),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Visualizar',
                                                      onPressed: () => _visualizar(r),
                                                      icon: const Icon(Icons.zoom_in),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Baixar',
                                                      onPressed: () => _baixar(r.id),
                                                      icon: const Icon(Icons.download),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total: $_total • Página $_page de $totalPages'),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Anterior',
                                      onPressed: _page > 1 && !_buscando ? () => _buscar(toPage: _page - 1) : null,
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    IconButton(
                                      tooltip: 'Próxima',
                                      onPressed: _page < totalPages && !_buscando ? () => _buscar(toPage: _page + 1) : null,
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}