import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/canhoto.dart';

class CanhotoRemoteService {
  final String baseUrl;

  final Map<String, String> headers = const {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  CanhotoRemoteService(this.baseUrl);

  /// ✅ Envia um canhoto para a API
  /// Retorna o novo ID gerado pelo servidor, ou null em caso de falha
  Future<int?> enviar(Canhoto c) async {
    final uri = Uri.parse('$baseUrl/canhotos');

    final body = {
      "idUsuario": c.idUsuario,
      "idEmpresa": c.idEmpresa,
      "numeroNota": c.numeroNota,
      "imagemBase64": base64Encode(c.imagemBytes),
    };

    final resp = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final json = jsonDecode(resp.body);

      // ✅ API retorna {"id": .., "dataHora": "..."} etc.
      return json["id"] is int
          ? json["id"]
          : int.tryParse(json["id"].toString());
    }

    return null;
  }

  /// ✅ Atualizar canhoto existente no servidor (se você quiser usar no futuro)
  Future<bool> atualizar(int id, Canhoto c) async {
    final uri = Uri.parse('$baseUrl/canhotos/$id');

    final body = {
      "idEmpresa": c.idEmpresa,
      "numeroNota": c.numeroNota,
      "imagemBase64": base64Encode(c.imagemBytes),
    };

    final resp = await http
        .put(
          uri,
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    return resp.statusCode == 200 || resp.statusCode == 204;
  }

  /// ✅ Excluir canhoto na API (usado se implementar exclusão offline)
  Future<bool> excluir(int id) async {
    final uri = Uri.parse('$baseUrl/canhotos/$id');

    final resp = await http
        .delete(
          uri,
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));

    return resp.statusCode == 200 || resp.statusCode == 204;
  }
}