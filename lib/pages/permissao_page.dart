import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:appcanhoto/core/api_config.dart';

/// =====================
/// MODELOS
/// =====================

/// ATENÇÃO: compatível com seu backend:
/// GET /api/usuarios -> [{ Id, Usuario, NomeCompleto }]
class Usuario {
  final int id;
  final String usuario;       // "Usuario" no backend
  final String? nomeCompleto; // "NomeCompleto" no backend
  Usuario({required this.id, required this.usuario, this.nomeCompleto});

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: (j['Id'] ?? j['id']) as int,
        usuario: (j['Usuario'] ?? j['usuario'] ?? '') as String,
        nomeCompleto: (j['NomeCompleto'] ?? j['nomeCompleto']) as String?,
      );
}

/// Permissao: { id, usuario, permissao }
class Permissao {
  final int id;
  final String usuario;
  final String permissao;

  Permissao({required this.id, required this.usuario, required this.permissao});

  factory Permissao.fromJson(Map<String, dynamic> j) => Permissao(
        id: (j['id'] ?? j['Id']) is int
            ? (j['id'] ?? j['Id'])
            : int.tryParse((j['id'] ?? j['Id']).toString()) ?? 0,
        usuario: (j['usuario'] ?? j['Usuario'] ?? '') as String,
        permissao: (j['permissao'] ?? j['Permissao'] ?? '') as String,
      );
}

/// =====================
/// PÁGINA
/// =====================

class PermissaoPage extends StatefulWidget {
  const PermissaoPage({super.key});

  @override
  State<PermissaoPage> createState() => _PermissaoPageState();
}

class _PermissaoPageState extends State<PermissaoPage> {
  // >>> Mesma lógica do seu RelatorioPage <<<
  // String get baseUrl {
  //   if (kIsWeb) return 'https://localhost:7245';
  //   if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5166';
  //   return 'http://localhost:5166';
  // }
  

  // // >>> ALTERAÇÃO AQUI: fixamos o IP/porta da sua API <<<
  // String get baseUrl {
  //   const host = '192.168.0.191';

  //   // HTTPS (requer certificado válido para o IP configurado no Kestrel)
  //   const httpsPort = 7245;
  //   return 'https://$host:$httpsPort';

  //   // Se preferir usar HTTP durante o dev, descomente abaixo:
  //   // const httpPort = 5166;
  
  //   // return 'http://$host:$httpPort';
  // }  

  String get baseUrl => '${ApiConfig.base}/api';

  Map<String, String> get _headers => const {
        'Accept': 'application/json', // igual ao seu exemplo
      };

  // Estado
  List<Usuario> _usuarios = [];
  List<Permissao> _permissoes = [];
  final _gruposFixos = const ['administrador', 'gerente', 'operador', 'cliente'];

  Usuario? _usuarioSel;
  String? _grupoSel;

  bool _loadingUsuarios = false;
  bool _loadingPermissoes = false;
  bool _salvando = false;
  bool _excluindo = false;

  // Para mostrar nome amigável no grid
  Map<String, String> _nomePorLogin = {};

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
    _carregarPermissoes();
  }

  // =====================
  // LOAD
  // =====================

  /// ATENÇÃO: mapeia para { Id, Usuario, NomeCompleto }
  Future<void> _carregarUsuarios() async {
    setState(() => _loadingUsuarios = true);
    try {
      final uri = Uri.parse('$baseUrl/usuarios');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data is List) ? data : (data['data'] ?? []);
        _usuarios = List<Map<String, dynamic>>.from(list).map(Usuario.fromJson).toList()
          ..sort((a, b) => (a.nomeCompleto ?? a.usuario).compareTo(b.nomeCompleto ?? b.usuario));

        _nomePorLogin = {for (final u in _usuarios) u.usuario: (u.nomeCompleto ?? u.usuario)};
      } else {
        _showSnack('Erro ao carregar usuários (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Falha ao carregar usuários. Verifique a API/CORS.');
    } finally {
      if (mounted) setState(() => _loadingUsuarios = false);
    }
  }

  Future<void> _carregarPermissoes() async {
    setState(() => _loadingPermissoes = true);
    try {
      final uri = Uri.parse('$baseUrl/permissoes');
      final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data is List) ? data : (data['data'] ?? []);
        _permissoes = List<Map<String, dynamic>>.from(list).map(Permissao.fromJson).toList()
          ..sort((a, b) => a.usuario.compareTo(b.usuario));
      } else {
        _showSnack('Erro ao carregar permissões (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Falha ao carregar permissões. Verifique a API/CORS.');
    } finally {
      if (mounted) setState(() => _loadingPermissoes = false);
    }
  }

  // =====================
  // AÇÕES
  // =====================

  Future<void> _salvar() async {
    if (_usuarioSel == null || _grupoSel == null) {
      _showSnack('Selecione um usuário e um grupo de permissão.');
      return;
    }
    setState(() => _salvando = true);
    try {
      final uri = Uri.parse('$baseUrl/permissoes');
      final body = jsonEncode({'usuario': _usuarioSel!.usuario, 'permissao': _grupoSel});
      final headers = {
        ..._headers,
        'Content-Type': 'application/json', // POST precisa content-type
      };
      final resp = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _showSnack('Permissão salva com sucesso!');
        await _carregarPermissoes();
        _limpar();
      } else {
        _showSnack('Erro ao salvar (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Falha ao salvar permissão. Verifique a API/CORS.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _limpar() {
    setState(() {
      _usuarioSel = null;
      _grupoSel = null;
    });
  }

  Future<void> _excluir(int id) async {
    setState(() => _excluindo = true);
    try {
      final uri = Uri.parse('$baseUrl/permissoes/$id');
      final resp = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        _showSnack('Permissão excluída.');
        await _carregarPermissoes();
      } else {
        _showSnack('Erro ao excluir (${resp.statusCode})');
      }
    } catch (e) {
      _showSnack('Falha ao excluir. Verifique a API/CORS.');
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  Future<void> _confirmarExclusao(Permissao p) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nomeBonito = _nomePorLogin[p.usuario] ?? p.usuario;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF121212) : null,
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a permissão de "$nomeBonito" (${p.permissao})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (ok == true) {
      await _excluir(p.id);
    }
  }

  // =====================
  // UI
  // =====================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissões'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : null,
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Usuario>(
                        initialValue: _usuarioSel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Usuário',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: _usuarios.map((u) {
                          final label = (u.nomeCompleto?.isNotEmpty ?? false) ? '${u.nomeCompleto} (${u.usuario})' : u.usuario;
                          return DropdownMenuItem<Usuario>(value: u, child: Text(label, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: _loadingUsuarios ? null : (u) => setState(() => _usuarioSel = u),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _grupoSel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Grupo de permissão',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        items: _gruposFixos.map((g) => DropdownMenuItem<String>(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => _grupoSel = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: (_salvando || _usuarioSel == null || _grupoSel == null) ? null : _salvar,
                      icon: _salvando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: const Text('Salvar'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _limpar,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Limpar'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Permissões cadastradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                if (_loadingPermissoes)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                else if (_permissoes.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Nenhum registro de permissão encontrado.')))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Usuário')),
                        DataColumn(label: Text('Permissão')),
                        DataColumn(label: Text('Ações')),
                      ],
                      rows: _permissoes.map((p) {
                        final nomeBonito = _nomePorLogin[p.usuario];
                        final usuarioExibir = nomeBonito != null ? '$nomeBonito (${p.usuario})' : p.usuario;
                        return DataRow(
                          cells: [
                            DataCell(Text(usuarioExibir)),
                            DataCell(Text(p.permissao)),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Excluir',
                                onPressed: _excluindo ? null : () => _confirmarExclusao(p),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}