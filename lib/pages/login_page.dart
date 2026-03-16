import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart'; // Shortcuts/Actions e teclas
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_page.dart';
import 'package:appcanhoto/core/api_config.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // ColorScheme realmente escuro
      colorScheme: const ColorScheme.dark(
        primary: Colors.blueAccent,
        secondary: Colors.blueAccent,
        surface: Colors.black,      // superfícies (cards, sheets, etc.)
        background: Colors.black,   // fundo
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),

      // Redundâncias úteis para evitar qualquer superfície clara
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: const Color(0xFF121212),
      dialogBackgroundColor: const Color(0xFF121212),

      // Inputs coerentes com dark
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
      // Força o dark mode independente do SO/navegador
      themeMode: ThemeMode.dark,
      theme: darkTheme, // (poderia ser colocado em darkTheme também)
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

  // FocusNodes para controlar "next"/"done"
  final FocusNode _usuarioFocus = FocusNode();
  final FocusNode _senhaFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _erroSenha;

  // String get baseUrl {
  //   if (kIsWeb) return 'https://localhost:7245';
  //   if (defaultTargetPlatform == TargetPlatform.android) {
  //     return 'http://10.0.2.2:5166';
  //   }
  //   return 'http://localhost:5166';
  // }
  // String get baseUrl {
  //   const host = '192.168.0.191';

  //   // Se você quer usar HTTP (recomendado durante o dev):
  //   //const httpPort = 5166;
  //   //return 'http://$host:$httpPort';

  //   // Caso queira forçar HTTPS (só se o cliente confiar no certificado):
  //    const httpsPort = 7245;
  //    return 'https://$host:$httpsPort';
  // }
  String get baseUrl => '${ApiConfig.base}/api';
  
  
  @override
  void dispose() {
    _usuarioController.dispose();
    _senhaController.dispose();
    _usuarioFocus.dispose();
    _senhaFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_loading) return; // evita duplo disparo
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
        final data = jsonDecode(response.body);
        final int idUsuario = data['id'];
        final String usuario = data['usuario'];

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

  // Intent/Action para acionar o login por Enter
  VoidCallbackIntent _loginIntent = const VoidCallbackIntent();
  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    VoidCallbackIntent: CallbackAction<VoidCallbackIntent>(onInvoke: (intent) {
      _login();
      return null;
    })
  };

  @override
  Widget build(BuildContext context) {
    // Mapeia Enter e NumpadEnter para nosso Intent (quando não está carregando)
    final shortcuts = <LogicalKeySet, Intent>{
      if (!_loading) LogicalKeySet(LogicalKeyboardKey.enter): _loginIntent,
      if (!_loading) LogicalKeySet(LogicalKeyboardKey.numpadEnter): _loginIntent,
    };

    return Scaffold(
      // Garante fundo preto no container do Scaffold
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

                        // Título branco no dark mode
                        const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // USUÁRIO
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

                        // SENHA
                        TextField(
                          controller: _senhaController,
                          focusNode: _senhaFocus,
                          obscureText: _obscurePassword,
                          onChanged: (_) => setState(() => _erroSenha = null),
                          onSubmitted: (_) => _login(),
                          textInputAction: TextInputAction.done,
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
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
          ),
        ),
      ),
    );
  }
}

// Intent vazio para bindar ao Shortcuts/Actions
class VoidCallbackIntent extends Intent {
  const VoidCallbackIntent();
}