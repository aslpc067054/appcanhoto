import 'package:flutter/material.dart';
import 'login_page.dart';
import 'configuracao_page.dart';
import 'canhoto_page.dart'; // <<< importe a tela de canhotos
import 'relatorio_page.dart'; // <<< NOVO: importe a tela de relatórios

class HomePage extends StatelessWidget {
  final int idUsuario; // <<< adicionado
  final String usuario;

  const HomePage({
    super.key,
    required this.idUsuario, // <<< adicionado
    required this.usuario,
  });

  void _logout(BuildContext context) async {
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

    Navigator.of(context).pushAndRemoveUntil(
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
          idUsuario: idUsuario, // passando o id do usuário logado
          usuarioNome: usuario, // passando o nome do usuário logado
        ),
      ),
    );
  }

  // >>> NOVO: abrir Relatórios
  void _abrirRelatorios(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RelatorioPage(
          usuarioLogado: usuario, // exibido no AppBar da página de relatório
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Bem-vindo, $usuario"),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : null,
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GridView(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 180 / 160,
              ),
              children: [
                // CANHOTOS -> abre CanhotoPage com id/nome do usuário
                _buildIcon(
                  context,
                  icon: Icons.person,
                  label: "Canhotos",
                  onTap: () => _abrirCanhotos(context),
                ),

                // >>> Atualizado: abre RelatorioPage
                _buildIcon(
                  context,
                  icon: Icons.shopping_cart,
                  label: "Relatórios",
                  onTap: () => _abrirRelatorios(context),
                ),

                _buildIcon(
                  context,
                  icon: Icons.settings,
                  label: "Configurações",
                  onTap: () => _abrirConfiguracoes(context),
                ),

                _buildIcon(
                  context,
                  icon: Icons.logout,
                  label: "Sair",
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ),
      ),
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
                    color: Colors.black.withOpacity(0.08),
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