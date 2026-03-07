import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

/// =========================
/// MODELOS
/// =========================

class Empresa {
  final int id;
  final String nomeFantasia;
  final int status; // 0=ativo, 1=inativo

  Empresa({required this.id, required this.nomeFantasia, required this.status});

  factory Empresa.fromJson(Map<String, dynamic> j) => Empresa(
        // aceita PascalCase e camelCase
        id: (j['Id'] ?? j['id']) is int
            ? (j['Id'] ?? j['id']) as int
            : int.parse((j['Id'] ?? j['id']).toString()),
        nomeFantasia: (j['NomeFantasia'] ?? j['nomeFantasia'] ?? j['nome_fantasia'] ?? '') as String,
        status: (j['Status'] ?? j['status']) is int
            ? (j['Status'] ?? j['status']) as int
            : int.tryParse('${j['Status'] ?? j['status']}') ?? 0,
      );
}

/// Registro exibido no grid
class Canhoto {
  final int? id; // null = pendente (ainda não sincronizado)
  final int idUsuario;
  final int idEmpresa;
  final String empresaNome;
  final String numeroNota;
  final DateTime dataHora;
  final Uint8List imagemBytes;
  final bool pendente; // true = offline aguardando sincronizar

  Canhoto({
    required this.id,
    required this.idUsuario,
    required this.idEmpresa,
    required this.empresaNome,
    required this.numeroNota,
    required this.dataHora,
    required this.imagemBytes,
    required this.pendente,
  });

  Canhoto copyWith({
    int? id,
    int? idUsuario,
    int? idEmpresa,
    String? empresaNome,
    String? numeroNota,
    DateTime? dataHora,
    Uint8List? imagemBytes,
    bool? pendente,
  }) {
    return Canhoto(
      id: id ?? this.id,
      idUsuario: idUsuario ?? this.idUsuario,
      idEmpresa: idEmpresa ?? this.idEmpresa,
      empresaNome: empresaNome ?? this.empresaNome,
      numeroNota: numeroNota ?? this.numeroNota,
      dataHora: dataHora ?? this.dataHora,
      imagemBytes: imagemBytes ?? this.imagemBytes,
      pendente: pendente ?? this.pendente,
    );
  }
}

/// Item de fila offline
enum OfflineOp { create, update, delete }

class CanhotoQueueItem {
  final OfflineOp op;
  final Canhoto canhoto; // quando delete, use id preenchido (se existir) ou algum marcador

  CanhotoQueueItem({required this.op, required this.canhoto});
}

/// =========================
/// PÁGINA
/// =========================
class CanhotoPage extends StatefulWidget {
  final int idUsuario;       // — passe o id do usuário logado
  final String usuarioNome;  // apenas para exibição

  const CanhotoPage({
    super.key,
    required this.idUsuario,
    required this.usuarioNome,
  });

  @override
  State<CanhotoPage> createState() => _CanhotoPageState();
}

class _CanhotoPageState extends State<CanhotoPage> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _notaCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController(); // usado pelo Autocomplete
  Empresa? _empresaSelecionada;

  Uint8List? _imagemAtual; // Foto selecionada/tirada (bytes)
  int? _editingId;         // Se != null, estamos editando um canhoto já sincronizado
  int? _editingIndex;      // índice na lista quando pendente

  // Listas
  List<Empresa> _empresasAtivas = [];
  List<Canhoto> _canhotosHoje = [];

  // Offline queue
  final List<CanhotoQueueItem> _filaOffline = [];

  // Estados
  bool _carregandoEmpresas = false;
  bool _carregandoHoje = false;
  bool _salvando = false;
  bool _online = true;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Feature flag: usar API (true) ou apenas memória (false)
  static const bool _usarApi = true;

  // FocusNodes para controlar foco e fechar o autocomplete
  FocusNode? _empresaFocusNode;     // recebe o focusNode fornecido pelo Autocomplete
  final _notaFocusNode = FocusNode(); // foco do campo de Nº da Nota

  String get baseUrl {
    if (kIsWeb) return 'https://localhost:7245';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5166';
    return 'http://localhost:5166';
  }

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _initPersistence();
    _carregarEmpresas();
    _carregarCanhotosDoDia();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    _empresaCtrl.dispose();
    _notaFocusNode.dispose(); // liberar foco da NF
    // _empresaFocusNode é gerenciado pelo Autocomplete; não chamamos dispose aqui.
    _connSub?.cancel();
    super.dispose();
  }

  void _initConnectivity() async {
    final conn = Connectivity();
    _online = await _isOnline(conn);
    _connSub = conn.onConnectivityChanged.listen((_) async {
      final wasOffline = !_online;
      _online = await _isOnline(conn);
      if (_online && wasOffline) {
        _showSnack('Conexão restabelecida. Sincronizando...');
        await _tentarSincronizarFila();
      } else if (!_online) {
        _showSnack('Sem conexão. Operando offline.');
      }
      setState(() {});
    });
  }

  Future<bool> _isOnline(Connectivity conn) async {
    final results = await conn.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  // === Persistência (Hive) ====

  // Salva a fila offline em disco
  Future<void> _saveQueueToDisk() async {
    final box = Hive.box('offline_queue');
    final list = _filaOffline.map((q) {
      final c = q.canhoto;
      return {
        'op': q.op.name, // 'create' | 'update' | 'delete'
        'canhoto': {
          'id': c.id,
          'idUsuario': c.idUsuario,
          'idEmpresa': c.idEmpresa,
          'empresaNome': c.empresaNome,
          'numeroNota': c.numeroNota,
          'dataHora': c.dataHora.toIso8601String(),
          'imagemBase64': base64Encode(c.imagemBytes),
          'pendente': c.pendente,
        }
      };
    }).toList();

    await box.put('canhotos_queue', list);
  }

  Future<void> _loadQueueFromDisk() async {
    final box = Hive.box('offline_queue');
    final raw = box.get('canhotos_queue') as List<dynamic>?;

    _filaOffline.clear();
    if (raw != null) {
      for (final item in raw) {
        final op = (item['op'] as String);
        final m = item['canhoto'] as Map;
        final c = Canhoto(
          id: m['id'] == null ? null : (m['id'] is int ? m['id'] : int.parse(m['id'].toString())),
          idUsuario: m['idUsuario'] as int,
          idEmpresa: m['idEmpresa'] as int,
          empresaNome: m['empresaNome'] as String,
          numeroNota: m['numeroNota'] as String,
          dataHora: DateTime.parse(m['dataHora'] as String),
          imagemBytes: base64Decode(m['imagemBase64'] as String),
          pendente: m['pendente'] as bool,
        );
        _filaOffline.add(CanhotoQueueItem(
          op: OfflineOp.values.firstWhere((e) => e.name == op),
          canhoto: c,
        ));
      }
    }
  }

  Future<void> _saveTodayListToDisk() async {
    final box = Hive.box('offline_queue');
    final list = _canhotosHoje.map((c) => {
          'id': c.id,
          'idUsuario': c.idUsuario,
          'idEmpresa': c.idEmpresa,
          'empresaNome': c.empresaNome,
          'numeroNota': c.numeroNota,
          'dataHora': c.dataHora.toIso8601String(),
          'imagemBase64': base64Encode(c.imagemBytes),
          'pendente': c.pendente,
        }).toList();
    await box.put('canhotos_hoje', list);
  }

  Future<void> _loadTodayListFromDisk() async {
    final box = Hive.box('offline_queue');
    final raw = box.get('canhotos_hoje') as List<dynamic>?;
    _canhotosHoje.clear();
    if (raw != null) {
      for (final m in raw) {
        _canhotosHoje.add(Canhoto(
          id: m['id'] == null ? null : (m['id'] is int ? m['id'] : int.parse(m['id'].toString())),
          idUsuario: m['idUsuario'] as int,
          idEmpresa: m['idEmpresa'] as int,
          empresaNome: m['empresaNome'] as String,
          numeroNota: m['numeroNota'] as String,
          dataHora: DateTime.parse(m['dataHora'] as String),
          imagemBytes: base64Decode(m['imagemBase64'] as String),
          pendente: m['pendente'] as bool,
        ));
      }
    }
  }

  // Chamar no initState para carregar o que ficou salvo
  Future<void> _initPersistence() async {
    await _loadQueueFromDisk();
    await _loadTodayListFromDisk(); // opcional (mostra os últimos do dia em cache)
    if (mounted) setState(() {});
  }

  // =========================
  // CARREGAMENTOS
  // =========================

  Future<void> _carregarEmpresas() async {
    setState(() => _carregandoEmpresas = true);
    try {
      if (_usarApi) {
        final uri = Uri.parse('$baseUrl/api/empresas');
        final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final List lista = (body is List) ? body : (body['data'] ?? []) as List;
          final empresas = lista.map((e) => Empresa.fromJson(e as Map<String, dynamic>)).toList();
          _empresasAtivas = empresas.where((e) => e.status == 0).toList()
            ..sort((a, b) => a.nomeFantasia.compareTo(b.nomeFantasia));
        } else {
          _showSnack('Erro ao carregar empresas (${resp.statusCode})');
        }
      }
    } catch (_) {
      _showSnack('Falha ao carregar empresas.');
    } finally {
      if (mounted) setState(() => _carregandoEmpresas = false);
    }
  }

  // GET paginado: lista de metadados (sem imagem) — APENAS do usuário logado
  Future<void> _carregarCanhotosDoDia({int page = 1, int pageSize = 20}) async {
    setState(() => _carregandoHoje = true);
    try {
      if (_usarApi) {
        final hoje = DateTime.now();
        final data =
            '${hoje.year.toString().padLeft(4, '0')}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}';

        // >>> Sempre enviar idUsuario no GET para filtrar no backend
        final uri = Uri.parse(
          '$baseUrl/api/canhotos?data=$data&page=$page&pageSize=$pageSize&idUsuario=${widget.idUsuario}',
        );

        final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200) {
          final json = jsonDecode(resp.body);
          final List lista = json['data'] as List;

          _canhotosHoje = lista
              .map((j) => Canhoto(
                    id: j['id'] is int ? j['id'] : int.parse(j['id'].toString()),
                    idUsuario: j['idUsuario'] as int,
                    idEmpresa: j['idEmpresa'] as int,
                    empresaNome: (j['empresaNome'] ?? '') as String,
                    numeroNota: (j['numeroNota'] ?? '') as String,
                    dataHora: DateTime.parse((j['dataHora'] as String)),
                    imagemBytes: Uint8List(0), // sem imagem por padrão
                    pendente: false,
                  ))
              .toList();

          // >>> Reforço: garante filtro local por usuário logado
          _canhotosHoje = _canhotosHoje.where((c) => c.idUsuario == widget.idUsuario).toList();

          // persiste a lista do dia em disco
          await _saveTodayListToDisk();
        } else {
          _showSnack('Erro ao carregar canhotos (${resp.statusCode})');
        }
      }
    } catch (_) {
      _showSnack('Falha ao carregar canhotos do dia.');
    } finally {
      if (mounted) setState(() => _carregandoHoje = false);
    }
  }

  // =========================
  // FOTO
  // =========================
  Future<void> _tirarOuSelecionarFoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? file;
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        // Mobile: tenta câmera; se cancelar, abre galeria
        file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
        file ??= await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      } else {
        // Web/desktop → file picker
        file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      }
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() => _imagemAtual = bytes);
      }
    } catch (e) {
      _showSnack('Falha ao obter a imagem.');
    }
  }

  // =========================
  // SALVAR / EDITAR / EXCLUIR
  // =========================

  bool _validarForm() {
    if (_empresaSelecionada == null) {
      _showSnack('Selecione a empresa');
      return false;
    }
    if (_notaCtrl.text.trim().isEmpty) {
      _showSnack('Informe o número da nota fiscal');
      return false;
    }
    if (_imagemAtual == null) {
      _showSnack('Selecione ou tire a foto do documento');
      return false;
    }
    return true;
  }

  Future<void> _salvar() async {
    if (!_validarForm()) return;
    setState(() => _salvando = true);

    try {
      final imgB64 = base64Encode(_imagemAtual!);

      // Edição de item pendente (sem id)
      if (_editingId == null && _editingIndex != null && _canhotosHoje[_editingIndex!].pendente) {
        final old = _canhotosHoje[_editingIndex!];
        final edited = old.copyWith(
          idEmpresa: _empresaSelecionada!.id,
          empresaNome: _empresaSelecionada!.nomeFantasia,
          numeroNota: _notaCtrl.text.trim(),
          imagemBytes: _imagemAtual!,
          dataHora: DateTime.now(),
        );
        _canhotosHoje[_editingIndex!] = edited;

        // Atualiza também a fila offline (update)
        final idxQ = _filaOffline.indexWhere((q) => q.canhoto == old);
        if (idxQ >= 0) {
          _filaOffline[idxQ] = CanhotoQueueItem(op: OfflineOp.update, canhoto: edited);
        }

        await _saveQueueToDisk();
        await _saveTodayListToDisk();

        _showSnack('Atualizado (pendente).');
        _limparForm();
        return;
      }

      if (_usarApi && _online) {
        if (_editingId == null) {
          // CREATE
          final uri = Uri.parse('$baseUrl/api/canhotos');
          final body = {
            'idUsuario': widget.idUsuario,
            'idEmpresa': _empresaSelecionada!.id,
            'numeroNota': _notaCtrl.text.trim(),
            'imagemBase64': imgB64,
          };
          final resp = await http.post(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
          if (resp.statusCode == 201 || resp.statusCode == 200) {
            final j = jsonDecode(resp.body) as Map<String, dynamic>;
            final novo = Canhoto(
              id: j['id'] is int ? j['id'] : int.parse(j['id'].toString()),
              idUsuario: widget.idUsuario,
              idEmpresa: _empresaSelecionada!.id,
              empresaNome: _empresaSelecionada!.nomeFantasia,
              numeroNota: _notaCtrl.text.trim(),
              dataHora: DateTime.parse(j['dataHora'] as String),
              imagemBytes: _imagemAtual!,
              pendente: false,
            );
            _canhotosHoje.insert(0, novo);
            await _saveTodayListToDisk();
            _showSnack('Canhoto salvo.');
            _limparForm();
          } else {
            _showSnack('Erro ao salvar (${resp.statusCode})');
          }
        } else {
          // UPDATE
          final uri = Uri.parse('$baseUrl/api/canhotos/$_editingId');
          final body = {
            'idEmpresa': _empresaSelecionada!.id,
            'numeroNota': _notaCtrl.text.trim(),
            'imagemBase64': imgB64,
          };
          final resp = await http.put(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
          if (resp.statusCode == 204 || resp.statusCode == 200) {
            final idx = _canhotosHoje.indexWhere((c) => c.id == _editingId);
            if (idx >= 0) {
              _canhotosHoje[idx] = _canhotosHoje[idx].copyWith(
                idEmpresa: _empresaSelecionada!.id,
                empresaNome: _empresaSelecionada!.nomeFantasia,
                numeroNota: _notaCtrl.text.trim(),
                imagemBytes: _imagemAtual!,
                dataHora: DateTime.now(),
              );
            }
            await _saveTodayListToDisk();
            _showSnack('Atualizado.');
            _limparForm();
          } else {
            _showSnack('Erro ao atualizar (${resp.statusCode})');
          }
        }
      } else {
        // OFFLINE → cria ou edita pendente
        if (_editingId == null) {
          final pendente = Canhoto(
            id: null,
            idUsuario: widget.idUsuario,
            idEmpresa: _empresaSelecionada!.id,
            empresaNome: _empresaSelecionada!.nomeFantasia,
            numeroNota: _notaCtrl.text.trim(),
            dataHora: DateTime.now(),
            imagemBytes: _imagemAtual!,
            pendente: true,
          );
          _canhotosHoje.insert(0, pendente);
          _filaOffline.add(CanhotoQueueItem(op: OfflineOp.create, canhoto: pendente));
          await _saveQueueToDisk();
          await _saveTodayListToDisk();
          _showSnack('Salvo localmente (offline).');
          _limparForm();
        } else {
          // Edição offline de item já sincronizado → enfileira update
          final idx = _canhotosHoje.indexWhere((c) => c.id == _editingId);
          if (idx >= 0) {
            final edited = _canhotosHoje[idx].copyWith(
              idEmpresa: _empresaSelecionada!.id,
              empresaNome: _empresaSelecionada!.nomeFantasia,
              numeroNota: _notaCtrl.text.trim(),
              imagemBytes: _imagemAtual!,
              dataHora: DateTime.now(),
              pendente: true, // marcar visualmente
            );
            _canhotosHoje[idx] = edited;
            _filaOffline.add(CanhotoQueueItem(op: OfflineOp.update, canhoto: edited));
            await _saveQueueToDisk();
            await _saveTodayListToDisk();
            _showSnack('Atualização pendente (offline).');
            _limparForm();
          }
        }
      }
    } catch (_) {
      _showSnack('Falha ao salvar.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir(Canhoto c) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir'),
        content: const Text('Deseja realmente excluir este registro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    // Pendente: remove da fila e da lista
    if (c.pendente && c.id == null) {
      _filaOffline.removeWhere((q) => q.canhoto == c);
      await _saveQueueToDisk();
      _canhotosHoje.remove(c);
      await _saveTodayListToDisk();
      setState(() {});
      _showSnack('Excluído localmente.');
      return;
    }

    // Com API online
    if (_usarApi && _online && c.id != null) {
      try {
        final uri = Uri.parse('$baseUrl/api/canhotos/${c.id}');
        final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 30));
        if (resp.statusCode == 204 || resp.statusCode == 200) {
          _canhotosHoje.removeWhere((x) => x.id == c.id);
          await _saveTodayListToDisk();
          setState(() {});
          _showSnack('Excluído.');
        } else {
          _showSnack('Erro ao excluir (${resp.statusCode})');
        }
      } catch (_) {
        _showSnack('Falha ao excluir.');
      }
    } else {
      // Offline → enfileira exclusão
      _filaOffline.add(CanhotoQueueItem(op: OfflineOp.delete, canhoto: c));
      await _saveQueueToDisk();
      _canhotosHoje.remove(c);
      await _saveTodayListToDisk();
      setState(() {});
      _showSnack('Exclusão pendente (offline).');
    }
  }

  Future<void> _tentarSincronizarFila() async {
    if (!_usarApi || !_online) return;
    // Processa em ordem de chegada
    final List<CanhotoQueueItem> processados = [];
    for (final item in _filaOffline) {
      try {
        if (item.op == OfflineOp.create) {
          final uri = Uri.parse('$baseUrl/api/canhotos');
          final body = {
            'idUsuario': item.canhoto.idUsuario,
            'idEmpresa': item.canhoto.idEmpresa,
            'numeroNota': item.canhoto.numeroNota,
            'imagemBase64': base64Encode(item.canhoto.imagemBytes),
          };
          final resp = await http.post(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
          if (resp.statusCode == 201 || resp.statusCode == 200) {
            final j = jsonDecode(resp.body) as Map<String, dynamic>;
            final novoId = j['id'] is int ? j['id'] : int.parse(j['id'].toString());
            // atualiza na lista (o mesmo objeto referenciado na fila)
            final idx = _canhotosHoje.indexWhere((c) => c == item.canhoto);
            if (idx >= 0) {
              _canhotosHoje[idx] = _canhotosHoje[idx].copyWith(
                id: novoId,
                dataHora: DateTime.parse(j['dataHora'] as String),
                pendente: false,
              );
            }
            processados.add(item);
          }
        } else if (item.op == OfflineOp.update) {
          // precisa de id; se não tiver, ignore
          if (item.canhoto.id == null) continue;
          final uri = Uri.parse('$baseUrl/api/canhotos/${item.canhoto.id}');
          final body = {
            'idEmpresa': item.canhoto.idEmpresa,
            'numeroNota': item.canhoto.numeroNota,
            'imagemBase64': base64Encode(item.canhoto.imagemBytes),
          };
          final resp = await http.put(uri, headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 60));
          if (resp.statusCode == 204 || resp.statusCode == 200) {
            final idx = _canhotosHoje.indexWhere((c) => c.id == item.canhoto.id);
            if (idx >= 0) {
              _canhotosHoje[idx] = _canhotosHoje[idx].copyWith(pendente: false, dataHora: DateTime.now());
            }
            processados.add(item);
          }
        } else if (item.op == OfflineOp.delete) {
          if (item.canhoto.id == null) {
            // era pendente: já removido localmente
            processados.add(item);
          } else {
            final uri = Uri.parse('$baseUrl/api/canhotos/${item.canhoto.id}');
            final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 30));
            if (resp.statusCode == 204 || resp.statusCode == 200) {
              processados.add(item);
            }
          }
        }
      } catch (_) {
        // mantém na fila para próxima tentativa
      }
    }
    // remove processados e persiste
    _filaOffline.removeWhere((e) => processados.contains(e));
    await _saveQueueToDisk();
    await _saveTodayListToDisk();
    setState(() {});
  }

  void _limparForm() {
    _notaCtrl.clear();
    _empresaCtrl.clear();
    _empresaSelecionada = null;
    _imagemAtual = null;
    _editingId = null;
    _editingIndex = null;
    setState(() {});
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Canhotos • ${widget.usuarioNome}'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : null,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Chip(
              backgroundColor: _online ? Colors.green : Colors.red,
              label: Text(_online ? 'ONLINE' : 'OFFLINE', style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await _carregarEmpresas();
          await _carregarCanhotosDoDia();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== FORM =====
            Card(
              color: isDark ? const Color(0xFF121212) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // Empresa (Autocomplete)
                      _carregandoEmpresas
                          ? const LinearProgressIndicator()
                          : Autocomplete<Empresa>(
                              displayStringForOption: (e) => e.nomeFantasia,
                              optionsBuilder: (TextEditingValue t) {
                                if (t.text.isEmpty) {
                                  return _empresasAtivas;
                                }
                                final txt = t.text.toLowerCase();
                                return _empresasAtivas.where((e) => e.nomeFantasia.toLowerCase().startsWith(txt));
                              },
                              fieldViewBuilder: (ctx, controller, focus, onFieldSubmit) {
                                _empresaFocusNode = focus; // guardamos o FocusNode do campo
                                controller.text = _empresaCtrl.text;
                                controller.selection = _empresaCtrl.selection;
                                controller.addListener(() {
                                  _empresaCtrl.value = controller.value;
                                });
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focus,
                                  decoration: const InputDecoration(
                                    labelText: 'Empresa (nome fantasia)',
                                    prefixIcon: Icon(Icons.apartment),
                                  ),
                                  validator: (_) => _empresaSelecionada == null ? 'Selecione a empresa' : null,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) => _notaFocusNode.requestFocus(), // pular para NF ao pressionar enter
                                );
                              },
                              onSelected: (e) {
                                _empresaSelecionada = e;
                                _empresaCtrl.text = e.nomeFantasia;

                                // fechar o overlay desfocando o campo
                                _empresaFocusNode?.unfocus();

                                // focar no campo da NF
                                _notaFocusNode.requestFocus();

                                setState(() {});
                              },
                              optionsViewBuilder: (ctx, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    child: SizedBox(
                                      height: 240,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        itemBuilder: (_, i) {
                                          final e = options.elementAt(i);
                                          return ListTile(
                                            title: Text(e.nomeFantasia),
                                            onTap: () {
                                              onSelected(e);
                                              FocusScope.of(ctx).unfocus();
                                              _notaFocusNode.requestFocus();
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 12),

                      // Nº Nota Fiscal
                      TextFormField(
                        controller: _notaCtrl,
                        focusNode: _notaFocusNode, // receber foco após selecionar empresa
                        decoration: const InputDecoration(
                          labelText: 'Nº Nota Fiscal',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nº da nota' : null,
                      ),
                      const SizedBox(height: 12),

                      // Imagem + botão
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.blue.shade100),
                              ),
                              child: _imagemAtual == null
                                  ? const Center(child: Text('Nenhuma imagem selecionada'))
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(_imagemAtual!, fit: BoxFit.cover, width: double.infinity),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              FilledButton.icon(
                                onPressed: _tirarOuSelecionarFoto,
                                icon: const Icon(Icons.photo_camera),
                                label: const Text('Foto/Selecionar'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => setState(() => _imagemAtual = null),
                                icon: const Icon(Icons.clear),
                                label: const Text('Limpar imagem'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _salvando ? null : _salvar,
                              icon: _salvando
                                  ? const SizedBox(
                                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save),
                              label: Text(_editingId == null ? 'Salvar' : 'Atualizar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _salvando ? null : _limparForm,
                              icon: const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Limpar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ===== GRID DO DIA =====
            Card(
              color: isDark ? const Color(0xFF121212) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _carregandoHoje
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _buildDataTable(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(BuildContext context) {
    if (_canhotosHoje.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Nenhum canhoto cadastrado hoje.')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Preview')),
          DataColumn(label: Text('Empresa')),
          DataColumn(label: Text('NF')),
          DataColumn(label: Text('Data/Hora')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Ações')),
        ],
        rows: _canhotosHoje.map((c) {
          final dt =
              '${c.dataHora.day.toString().padLeft(2, '0')}/${c.dataHora.month.toString().padLeft(2, '0')}/${c.dataHora.year} '
              '${c.dataHora.hour.toString().padLeft(2, '0')}:${c.dataHora.minute.toString().padLeft(2, '0')}';

          return DataRow(
            cells: [
              DataCell(
                SizedBox(
                  width: 90,
                  height: 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: c.imagemBytes.isEmpty
                        ? Container(
                            color: Colors.black12,
                            child: const Icon(Icons.image_not_supported, size: 28),
                          )
                        : Image.memory(c.imagemBytes, fit: BoxFit.cover),
                  ),
                ),
              ),
              DataCell(Text(c.empresaNome)),
              DataCell(Text(c.numeroNota)),
              DataCell(Text(dt)),
              DataCell(
                Chip(
                  label: Text(c.pendente ? 'PENDENTE' : 'SINCRONIZADO'),
                  backgroundColor: c.pendente ? Colors.orange : Colors.green,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit),
                      color: isDark ? Colors.white : Colors.blueGrey,
                      onPressed: () {
                        // carregar form
                        _empresaSelecionada = _empresasAtivas.firstWhere(
                          (e) => e.id == c.idEmpresa,
                          orElse: () => Empresa(id: c.idEmpresa, nomeFantasia: c.empresaNome, status: 0),
                        );
                        _empresaCtrl.text = _empresaSelecionada!.nomeFantasia;
                        _notaCtrl.text = c.numeroNota;
                        _imagemAtual = c.imagemBytes.isEmpty ? null : c.imagemBytes;

                        if (c.id != null) {
                          _editingId = c.id;
                          _editingIndex = null;
                        } else {
                          _editingId = null;
                          _editingIndex = _canhotosHoje.indexOf(c);
                        }
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.redAccent,
                      onPressed: () => _excluir(c),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}