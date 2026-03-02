import 'package:flutter/material.dart';
import 'package:appcanhoto/pages/cadatro_usuario_page.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildIcon(
              context,
              Icons.settings,
              "Usuários",
              onTap: () {
                // TODO: Navegar para tela de Usuários
               Navigator.push(context, MaterialPageRoute(builder: (_) => CadastroUsuarioPage()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abrir: Usuários')),
                );
              },
            ),
            _buildIcon(
              context,
              Icons.settings,
              "Acessos",
              onTap: () {
                // TODO: Navegar para tela de Acessos/Perfis/Permissões
                // Navigator.push(context, MaterialPageRoute(builder: (_) => AcessosPage()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abrir: Acessos')),
                );
              },
            ),
            _buildIcon(
              context,
              Icons.settings,
              "Empresas",
              onTap: () {
                // TODO: Navegar para tela de Empresas
                // Navigator.push(context, MaterialPageRoute(builder: (_) => EmpresasPage()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Abrir: Empresas')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
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
            Icon(
              icon,
              size: 50,
              color: isDark ? Colors.white : Colors.blue,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}