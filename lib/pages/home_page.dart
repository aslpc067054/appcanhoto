import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_page.dart';
import 'configuracao_page.dart';
import 'canhoto_page.dart';
import 'relatorio_page.dart';
import 'package:appcanhoto/core/api_config.dart';

class HomePage extends StatefulWidget {
  final int idUsuario;
  final String usuario;

  const HomePage({
    super.key,
    required this.idUsuario,
    required this.usuario,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // >>> NOVO: estado para permissão
  String? _permissao; // 'cliente' | 'operador' | 'gerente' | 'administrador'
  bool _carregando = true;
  String? _erro;

  // >>> Ajuste para sua API
  //static const String apiBaseUrl = 'https://localhost:7245/api/permissoes';
//static const String apiBaseUrl = 'https://192.168.0.191:7245/api/permissoes';
static String get apiBaseUrl => '${ApiConfig.base}/api/permissoes';

  @override
  void initState() {
    super.initState();
    _carregarPermissao();
  }

  Future<void> _carregarPermissao() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final uri = Uri.parse('$apiBaseUrl/usuario/${Uri.encodeComponent(widget.usuario)}/atual');
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final p = (data['permissao'] as String?)?.toLowerCase().trim();
        if (p == null || p.isEmpty) {
          setState(() {
            _erro = 'Permissão vazia.';
            _carregando = false;
          });
          return;
        }
        setState(() {
          _permissao = p;
          _carregando = false;
        });
      } else if (resp.statusCode == 404) {
        setState(() {
          _erro = 'Permissão não encontrada para o usuário.';
          _carregando = false;
        });
      } else {
        setState(() {
          _erro = 'Falha ao obter permissão (HTTP ${resp.statusCode}).';
          _carregando = false;
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar permissão: $e';
        _carregando = false;
      });
    }
  }

  // ==== Ações já existentes ====
  void _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente encerrar a sessão?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmar != true) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _abrirConfiguracoes(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfiguracaoPage()));
  }

  void _abrirCanhotos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CanhotoPage(
          idUsuario: widget.idUsuario,
          usuarioNome: widget.usuario,
        ),
      ),
    );
  }

  void _abrirRelatorios(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RelatorioPage(
          usuarioLogado: widget.usuario,
        ),
      ),
    );
  }

  // >>> NOVO: monta a lista de botões conforme a permissão,
//          mantendo "Sair" sempre por último.
List<Widget> _construirAcoesPorPermissao(BuildContext context) {
  final p = _permissao; // já em minúsculas

  // Ordem desejada: Relatórios, Canhotos, Configurações, Sair
  final List<Widget> itens = [];

  // Relatórios (cliente, operador, gerente, administrador)
  if (p == 'cliente' || p == 'operador' || p == 'gerente' || p == 'administrador') {
    itens.add(_buildIcon(
      context,
      icon: Icons.shopping_cart,
      label: "Relatórios",
      onTap: () => _abrirRelatorios(context),
    ));
  }

  // Canhotos (operador, gerente, administrador)
  if (p == 'operador' || p == 'gerente' || p == 'administrador') {
    itens.add(_buildIcon(
      context,
      icon: Icons.person,
      label: "Canhotos",
      onTap: () => _abrirCanhotos(context),
    ));
  }

  // Configurações (gerente, administrador)
  if (p == 'gerente' || p == 'administrador') {
    itens.add(_buildIcon(
      context,
      icon: Icons.settings,
      label: "Configurações",
      onTap: () => _abrirConfiguracoes(context),
    ));
  }

  // >>> Sair SEMPRE por último
  itens.add(_buildIcon(
    context,
    icon: Icons.logout,
    label: "Sair",
    onTap: () => _logout(context),
  ));

  return itens;
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Bem-vindo, ${widget.usuario}"),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : null,
        actions: [
          // >>> botão para recarregar a permissão
          IconButton(
            tooltip: 'Recarregar permissão',
            onPressed: _carregando ? null : _carregarPermissao,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : (_erro != null)
                    ? _erroWidget(context, _erro!)
                    : GridView(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 180 / 160,
                        ),
                        // >>> SOMENTE os botões permitidos
                        children: _construirAcoesPorPermissao(context),
                      ),
          ),
        ),
      ),
    );
  }

  Widget _erroWidget(BuildContext context, String mensagem) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: isDark ? Colors.red[300] : Colors.red[700]),
        const SizedBox(height: 12),
        Text(
          mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _carregarPermissao,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }

  Widget _buildIcon(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: SizedBox(
          width: 180,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121212) : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(16),
              border: isDark ? Border.all(color: Colors.white10) : null,
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 42, color: isDark ? Colors.white : Colors.blue),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}