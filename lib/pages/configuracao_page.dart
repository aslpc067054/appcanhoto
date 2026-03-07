import 'package:flutter/material.dart';
import 'package:appcanhoto/pages/cadastro_usuario_page.dart';
import 'package:appcanhoto/pages/cadastro_empresa_page.dart';
import 'package:appcanhoto/pages/permissao_page.dart'; // <<< novo import

class ConfiguracaoPage extends StatelessWidget {
  const ConfiguracaoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
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
                _buildIcon(
                  context,
                  icon: Icons.settings,
                  label: "Usuários",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroUsuarioPage()));
                  },
                ),
                _buildIcon(
                  context,
                  icon: Icons.settings,
                  label: "Permissões",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissaoPage()));
                  },
                ),
                _buildIcon(
                  context,
                  icon: Icons.settings,
                  label: "Empresas",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CadastroEmpresaPage()));
                  },
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
