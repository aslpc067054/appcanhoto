import 'package:flutter/material.dart';
import 'login_page.dart'; // ajuste o import conforme o seu package name/caminho real

class HomePage extends StatelessWidget {
  final String usuario;

  const HomePage({super.key, required this.usuario});

  void _logout(BuildContext context) async {
    // (Opcional) Se quiser confirmar o logout, descomente este bloco:
    
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
    

    // Navega para a tela de Login e remove toda a pilha de rotas
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bem-vindo, $usuario"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildIcon(Icons.person, "Perfil"),
            _buildIcon(Icons.shopping_cart, "Pedidos"),
            _buildIcon(Icons.settings, "Configurações"),

            // SAIR
            _buildIcon(
              Icons.logout,
              "Sair",
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.blue),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}