import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  final Connectivity _conn = Connectivity();

  /// ✅ Stream que notifica sempre que o tipo de conexão muda
  Stream<List<ConnectivityResult>> get onChange =>
      _conn.onConnectivityChanged;

  /// ✅ Verifica se existe conexão REAL com a internet
  /// Faz um request ultra-rápido e seguro
  Future<bool> hasInternet() async {
    final results = await _conn.checkConnectivity();

    // Sem nenhum tipo de rede disponível
    if (results.contains(ConnectivityResult.none)) return false;

    try {
      // Testa conexão real
      final sw = Stopwatch()..start();

      final resp = await http
          .get(Uri.parse("https://www.google.com"))
          .timeout(const Duration(seconds: 2));

      // ✅ Considera internet OK com latência boa (< 900ms)
      return sw.elapsedMilliseconds < 900;
    } catch (_) {
      return false;
    }
  }
}