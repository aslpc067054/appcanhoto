import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'package:appcanhoto/core/api_config.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Colors.blueAccent,
        secondary: Colors.blueAccent,
        surface: Colors.black,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: const Color(0xFF121212),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF121212),
      ),
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
        suffixIconColor: Colors.white70,
        iconColor: Colors.white70,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
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

  final FocusNode _usuarioFocus = FocusNode();
  final FocusNode _senhaFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _erroSenha;

  bool _memorizar = false; // ✅ checkbox ativado

  String get baseUrl => '${ApiConfig.base}/api';

  @override
  void initState() {
    super.initState();
    _carregarCredenciais();
  }

  // ✅ Preenche usuário e senha, MAS NÃO faz auto-login
  Future<void> _carregarCredenciais() async {
    final prefs = await SharedPreferences.getInstance();

    final user = prefs.getString('usuario');
    final pass = prefs.getString('senha');
    final remember = prefs.getBool('memorizar') ?? false;

    if (remember && user != null && pass != null) {
      setState(() {
        _memorizar = true;
        _usuarioController.text = user;
        _senhaController.text = pass;
      });
    }
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    _usuarioFocus.dispose();
    _senhaFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return;

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

    final uri = Uri.parse('$baseUrl/login');
    debugPrint('[LOGIN] POST $uri');

    try {
      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"usuario": usuarioInput, "senha": senha}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final idUsuario = data['id'];
        final usuario = data['usuario'];

        // ✅ Salva ou limpa credenciais
        final prefs = await SharedPreferences.getInstance();
        if (_memorizar) {
          await prefs.setString('usuario', usuarioInput);
          await prefs.setString('senha', senha);
          await prefs.setBool('memorizar', true);
        } else {
          await prefs.remove('usuario');
          await prefs.remove('senha');
          await prefs.setBool('memorizar', false);
        }

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(
              idUsuario: idUsuario,
              usuario: usuario,
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        setState(() => _erroSenha = "Usuário ou senha inválidos");
        _senhaController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Usuário ou senha inválidos"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ${response.statusCode}: ${response.body}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
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

  final VoidCallbackIntent _loginIntent = const VoidCallbackIntent();
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    VoidCallbackIntent: CallbackAction<VoidCallbackIntent>(onInvoke: (_) {
      _login();
      return null;
    })
  };

  @override
  Widget build(BuildContext context) {
    final shortcuts = <LogicalKeySet, Intent>{
      if (!_loading) LogicalKeySet(LogicalKeyboardKey.enter): _loginIntent,
      if (!_loading) LogicalKeySet(LogicalKeyboardKey.numpadEnter): _loginIntent,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Shortcuts(
                shortcuts: shortcuts,
                child: Actions(
                  actions: _actions,
                  child: FocusScope(
                    autofocus: true,
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
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 30),

                        TextField(
                          controller: _usuarioController,
                          focusNode: _usuarioFocus,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Usuário",
                            prefixIcon: Icon(Icons.person),
                          ),
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _senhaFocus.requestFocus(),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _senhaController,
                          focusNode: _senhaFocus,
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(() => _erroSenha = null),
                          onSubmitted: (_) => _login(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Senha",
                            prefixIcon: const Icon(Icons.lock),
                            errorText: _erroSenha,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Checkbox(
                              value: _memorizar,
                              onChanged: (value) {
                                setState(() {
                                  _memorizar = value ?? false;
                                });
                              },
                              activeColor: Colors.blueAccent,
                            ),
                            const Text(
                              "Memorizar usuário",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            onPressed: _loading ? null : () => _login(),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text("Entrar", style: TextStyle(fontSize: 16)),
                          ),
                        ),


                        const SizedBox(height: 10),

                        const Text(
                          "BY TecnoIntegra V1.1.9",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54, // discreto mas visível
                            letterSpacing: 0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VoidCallbackIntent extends Intent {
  const VoidCallbackIntent();
}