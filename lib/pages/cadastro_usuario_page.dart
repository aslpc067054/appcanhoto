import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Modelo simples de usuário (ajuste conforme sua API, se necessário)
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

  Map<String, String> get _headers => const {
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

  // ==========================
  // CRUD - API CALLS
  // ==========================

  Future<void> _carregarUsuarios() async {
    setState(() => _loadingLista = true);
    try {
      final uri = Uri.parse('$baseUrl/api/usuarios');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);

        // A API retorna uma lista direta de objetos [{id, usuario, nomeCompleto}]
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

  Future<void> _salvar() async {
    // Faz a validação dos campos do Form (mostra mensagens nos campos também)
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;

    final usuario = _usuarioCtrl.text.trim();
    final nome = _nomeCtrl.text.trim();
    final senha = _senhaCtrl.text; // AGORA É OBRIGATÓRIA, inclusive na edição

    // Payload SEMPRE com senha
    final payload = {
      'usuario': usuario,
      'nomeCompleto': nome,
      'senha': senha,
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

      if (resp.statusCode == 201) {
        _showSnack('Usuário cadastrado com sucesso.');
        _limparCampos();
        await _carregarUsuarios();
      } else if (resp.statusCode == 200 || resp.statusCode == 204) {
        _showSnack('Usuário atualizado com sucesso.');
        _limparCampos();
        await _carregarUsuarios();
      } else if (resp.statusCode == 400) {
        _showSnack('Dados inválidos: ${resp.body}');
      } else if (resp.statusCode == 409) {
        _showSnack('Usuário já existente.');
      } else if (resp.statusCode == 404) {
        _showSnack('Usuário não encontrado (404).');
      } else {
        _showSnack('Erro ao salvar (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      _showSnack('Falha de conexão ao salvar.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluirUsuario(int id) async {
    setState(() => _excluindoId = id);
    try {
      final uri = Uri.parse('$baseUrl/api/usuarios/$id');
      final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200 || resp.statusCode == 202 || resp.statusCode == 204) {
        // Remover localmente para resposta imediata
        _usuarios.removeWhere((x) => x.id == id);
        setState(() {});
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

  // ==========================
  // UI helpers
  // ==========================

  /// Agora os 3 campos são OBRIGATÓRIOS sempre (inclusive na edição).
  bool _validarCampos() {
    final usuario = _usuarioCtrl.text.trim();
    final nome = _nomeCtrl.text.trim();
    final senha = _senhaCtrl.text;

    if (usuario.isEmpty || nome.isEmpty || senha.isEmpty) {
      _showSnack('Preencha Usuário, Nome completo e Senha.');
      return false;
    }
    return true;
  }

  void _editar(Usuario u) {
    setState(() {
      _editingId = u.id;
      _usuarioCtrl.text = u.usuario;
      _nomeCtrl.text = u.nomeCompleto;
      _senhaCtrl.clear(); // por segurança, peça para informar a nova senha
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

  void _limparCampos() {
    _usuarioCtrl.clear();
    _nomeCtrl.clear();
    _senhaCtrl.clear();
    setState(() {
      _editingId = null;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ==========================
  // BUILD
  // ==========================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId == null ? 'Cadastro de Usuário' : 'Editar Usuário'),
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
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // Usuário (obrigatório)
                      TextFormField(
                        controller: _usuarioCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o usuário';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Nome completo (obrigatório)
                      TextFormField(
                        controller: _nomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          prefixIcon: Icon(Icons.badge),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o nome completo';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Senha (obrigatória sempre)
                      TextFormField(
                        controller: _senhaCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: Icon(Icons.lock),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Informe a senha';
                          if (v.length < 3) return 'Senha muito curta';
                          return null;
                        },
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
                              onPressed: _salvando
                                  ? null
                                  : () {
                                      // validação visual do Form + validação adicional
                                      if ((_formKey.currentState?.validate() ?? false) && _validarCampos()) {
                                        _salvar();
                                      }
                                    },
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

    // Permite rolagem horizontal se a tela for estreita
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