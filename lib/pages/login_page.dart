import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Color(0xFF121212),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent),
        ),
        prefixIconColor: Colors.white70,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: darkTheme,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _erroSenha;

  String get baseUrl {
    if (kIsWeb) return 'https://localhost:7245';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5166';
    }
    return 'http://localhost:5166';
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final usuarioInput = _usuarioController.text.trim();
    final senha = _senhaController.text.trim();

    if (usuarioInput.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha usuário e senha")),
      );
      return;
    }

    setState(() {
      _loading = true;
      _erroSenha = null;
    });

    final uri = Uri.parse('$baseUrl/api/login');
    debugPrint('[LOGIN] POST $uri');
    debugPrint('[LOGIN] Usuario="$usuarioInput"');

    try {
      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"usuario": usuarioInput, "senha": senha}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[LOGIN] status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200) {
        // ✅ Apenas uma leitura do body e uma navegação
        final data = jsonDecode(response.body);
        final int idUsuario = data['id'];
        final String usuario = data['usuario'];

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              idUsuario: idUsuario, // HomePage agora exige idUsuario
              usuario: usuario,
            ),
          ),
        );

      } else if (response.statusCode == 401) {
        setState(() => _erroSenha = "Usuário ou senha inválidos");
        _senhaController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Usuário ou senha inválidos"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ${response.statusCode}: ${response.body}")),
        );
      }
    } on http.ClientException catch (e) {
      debugPrint('[LOGIN] ClientException: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Falha de conexão (ClientException)"),
          backgroundColor: Colors.red,
        ),
      );
    } on FormatException catch (e) {
      debugPrint('[LOGIN] FormatException: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Resposta inválida da API"),
          backgroundColor: Colors.red,
        ),
      );
    } on Exception catch (e) {
      debugPrint('[LOGIN] Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao conectar na API"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'lib/assets/img/logo_express_show.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0), // título branco
                    ),
                  ),
                  const SizedBox(height: 30),

                  // USUÁRIO
                  TextField(
                    controller: _usuarioController,
                    style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    decoration: const InputDecoration(
                      labelText: "Usuário",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SENHA
                  TextField(
                    controller: _senhaController,
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() => _erroSenha = null),
                    style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                    decoration: InputDecoration(
                      labelText: "Senha",
                      prefixIcon: const Icon(Icons.lock),
                      errorText: _erroSenha,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: const Color.fromARGB(179, 0, 0, 0),
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _loading
                          ? null
                          : () {
                              debugPrint('[LOGIN] Botão "Entrar" clicado');
                              _login();
                            },
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color.fromARGB(255, 0, 0, 0)),
                            )
                          : const Text("Entrar", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}