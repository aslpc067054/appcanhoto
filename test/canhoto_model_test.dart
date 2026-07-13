import 'package:flutter_test/flutter_test.dart';
import 'package:appcanhoto/models/canhoto.dart';
import 'package:appcanhoto/models/sync_status.dart';

void main() {
  group('Canhoto.fromMap', () {
    test('deve aceitar dados sem imagem e retornar bytes vazios', () {
      final now = DateTime.now().toIso8601String();

      final canhoto = Canhoto.fromMap({
        'id': 1,
        'idUsuario': 10,
        'idEmpresa': 20,
        'empresaNome': 'Empresa Teste',
        'numeroNota': '123',
        'dataHora': now,
        'status': SyncStatus.pending.name,
      });

      expect(canhoto.imagemBytes, isEmpty);
      expect(canhoto.status, SyncStatus.pending);
    });

    test('deve aceitar imagemBase64 em branco como bytes vazios', () {
      final now = DateTime.now().toIso8601String();

      final canhoto = Canhoto.fromMap({
        'id': 1,
        'idUsuario': 10,
        'idEmpresa': 20,
        'empresaNome': 'Empresa Teste',
        'numeroNota': '123',
        'dataHora': now,
        'imagemBase64': '',
        'status': SyncStatus.pending.name,
      });

      expect(canhoto.imagemBytes, isEmpty);
    });
  });
}
