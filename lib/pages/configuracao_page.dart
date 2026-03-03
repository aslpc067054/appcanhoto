import 'package:flutter/material.dart';
import 'package:appcanhoto/pages/cadastro_usuario_page.dart';
import 'package:appcanhoto/pages/cadastro_empresa_page.dart'; // <<< import da tela de empresas

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

      // Centraliza e limita a largura total para evitar cards gigantes em telas largas
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900), // largura máxima da grade
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GridView(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,            // largura máx. por card
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 180 / 160,        // mantém a proporção visual
              ),
              children: [
                // USUÁRIOS
                _buildIcon(
                  context,
                  icon: Icons.settings,
                  label: "Usuários",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CadastroUsuarioPage()),
                    );
                  },
                ),

                // ACESSOS
                _buildIcon(
                  context,
                  icon: Icons.settings,
                  label: "Acessos",
                  onTap: () {
                    // TODO: Navegar para Acessos/Perfis/Permissões
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abrir: Acessos')),
                    );
                  },
                ),

                // EMPRESAS -> abre CadastroEmpresaPage
                _buildIcon(
                  context,
                  icon: Icons.settings,
                  label: "Empresas",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CadastroEmpresaPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card com tamanho controlado (consistente com a Home)
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
        child: SizedBox( // controla o tamanho do card
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
                Icon(icon, size: 42, color: isDark ? Colors.white : Colors.blue), // ícone menor fixo
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15, // fonte fixa
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