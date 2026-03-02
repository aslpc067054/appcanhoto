import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Modelo simples de usuário (ajuste conforme sua API)
class Usuario {
  final int id;
  final String usuario;
  final String nomeCompleto;

  Usuario({
    required this.id,
    required this.usuario,
    required this.nomeCompleto,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      usuario: json['usuario'] as String,
      nomeCompleto: (json['nomeCompleto'] ?? json['nome_completo'] ?? '') as String,
    );
  }
}

class CadastroUsuarioPage extends StatefulWidget {
  const CadastroUsuarioPage({super.key});

  @override
  State<CadastroUsuarioPage> createState() => _CadastroUsuarioPageState();
}

class _CadastroUsuarioPageState extends State<CadastroUsuarioPage> {
  final _formKey = GlobalKey<FormState>();

  final _usuarioCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();

  /// Quando não for nulo, estamos editando (PUT); quando for nulo, é novo (POST)
  int? _editingId;

  /// Lista do grid
  List<Usuario> _usuarios = [];

  /// Flags de estado
  bool _loadingLista = false;
  bool _salvando = false;
  int? _excluindoId; // id do usuário que está sendo excluído no momento

  /// Define a baseUrl conforme a plataforma (igual ao seu padrão)
  String get baseUrl {
    if (kIsWeb) return 'https://localhost:7245'; // Web → porta HTTPS correta
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5166'; // Android emulador
    }
    return 'http://localhost:5166'; // iOS simulador / desktop
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _nomeCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuarios() async {
    setState(() => _loadingLista = true);
    try {
      final uri = Uri.parse('$baseUrl/api/usuarios');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final list = (body is List) ? body : (body['data'] ?? []) as List;
        _usuarios = list.map((e) => Usuario.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        _showSnack('Erro ao consultar usuários (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Falha ao consultar usuários');
    } finally {
      if (mounted) setState(() => _loadingLista = false);
    }
  }

  void _limparCampos() {
    _usuarioCtrl.clear();
    _nomeCtrl.clear();
    _senhaCtrl.clear();
    setState(() {
      _editingId = null;
    });
  }

  Future<void> _salvar() async {
    if (!_validarCampos()) return;

    final usuario = _usuarioCtrl.text.trim();
    final nome = _nomeCtrl.text.trim();
    final senha = _senhaCtrl.text; // pode ser vazio em edição, se sua API aceitar

    final payload = {
      'usuario': usuario,
      'nomeCompleto': nome, // ajuste chave conforme sua API
      // Em edição, algumas APIs permitem senha opcional; em criação, geralmente é obrigatório
      if (_editingId == null || senha.isNotEmpty) 'senha': senha,
    };

    setState(() => _salvando = true);
    try {
      http.Response resp;
      if (_editingId == null) {
        // CREATE
        final uri = Uri.parse('$baseUrl/api/usuarios');
        resp = await http
            .post(uri, headers: _headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 20));
      } else {
        // UPDATE
        final uri = Uri.parse('$baseUrl/api/usuarios/$_editingId');
        resp = await http
            .put(uri, headers: _headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 20));
      }

      if (resp.statusCode == 200 || resp.statusCode == 201 || resp.statusCode == 204) {
        _showSnack(_editingId == null ? 'Usuário cadastrado com sucesso.' : 'Usuário atualizado com sucesso.');
        _limparCampos();
        await _carregarUsuarios();
      } else if (resp.statusCode == 400) {
        _showSnack('Dados inválidos: ${resp.body}');
      } else if (resp.statusCode == 409) {
        _showSnack('Usuário já existente.');
      } else {
        _showSnack('Erro ao salvar (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      _showSnack('Falha de conexão ao salvar.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  bool _validarCampos() {
    final usuario = _usuarioCtrl.text.trim();
    final nome = _nomeCtrl.text.trim();
    final senha = _senhaCtrl.text;

    if (usuario.isEmpty || nome.isEmpty) {
      _showSnack('Preencha Usuário e Nome completo.');
      return false;
    }
    if (_editingId == null && senha.isEmpty) {
      _showSnack('Informe uma senha para criar o usuário.');
      return false;
    }
    return true;
  }

  void _editar(Usuario u) {
    setState(() {
      _editingId = u.id;
      _usuarioCtrl.text = u.usuario;
      _nomeCtrl.text = u.nomeCompleto;
      _senhaCtrl.clear(); // não carregamos senha
    });
    _showSnack('Modo edição: ${u.usuario}');
  }

  Future<void> _confirmarExclusao(Usuario u) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Tem certeza que deseja excluir "${u.usuario}"? Esta ação não poderá ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _excluirUsuario(u.id);
    }
  }

  Future<void> _excluirUsuario(int id) async {
    setState(() => _excluindoId = id);
    try {
      final uri = Uri.parse('$baseUrl/api/usuarios/$id');
      final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200 || resp.statusCode == 202 || resp.statusCode == 204) {
        // Remover localmente para sentir a resposta imediata
        _usuarios.removeWhere((x) => x.id == id);
        setState(() {}); // atualiza grid
        _showSnack('Usuário excluído com sucesso.');
      } else if (resp.statusCode == 404) {
        _showSnack('Usuário não encontrado (404).');
        await _carregarUsuarios();
      } else if (resp.statusCode == 409) {
        _showSnack('Não foi possível excluir: conflito (409).');
      } else {
        _showSnack('Erro ao excluir (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      _showSnack('Falha de conexão ao excluir.');
    } finally {
      if (mounted) setState(() => _excluindoId = null);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId == null ? 'Cadastro de Usuário' : 'Editar Usuário (#$_editingId)'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : null,
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: RefreshIndicator(
        onRefresh: _carregarUsuarios,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ======= CARD FORM =======
            Card(
              color: isDark ? const Color(0xFF121212) : null,
              elevation: isDark ? 0 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Usuário
                      TextFormField(
                        controller: _usuarioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Nome completo
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Senha (em edição pode ficar vazia, se sua API aceitar)
                      TextFormField(
                        controller: _senhaCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: _salvando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_editingId == null ? 'Salvar' : 'Atualizar'),
                              onPressed: _salvando ? null : _salvar,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Limpar'),
                              onPressed: _salvando ? null : _limparCampos,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
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

            // ======= CARD GRID =======
            Card(
              color: isDark ? const Color(0xFF121212) : null,
              elevation: isDark ? 0 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _loadingLista
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_usuarios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Nenhum usuário cadastrado.')),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Usuário')),
          DataColumn(label: Text('Nome completo')),
          DataColumn(label: Text('Ações')),
        ],
        rows: _usuarios.map((u) {
          final excluindo = _excluindoId == u.id;

          return DataRow(
            cells: [
              DataCell(Text(u.usuario)),
              DataCell(Text(u.nomeCompleto)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDITAR
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit),
                      color: isDark ? Colors.white : Colors.blueGrey,
                      onPressed: () => _editar(u),
                    ),
                    const SizedBox(width: 4),
                    // EXCLUIR
                    excluindo
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                          )
                        : IconButton(
                            tooltip: 'Excluir',
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.redAccent,
                            onPressed: () => _confirmarExclusao(u),
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
}