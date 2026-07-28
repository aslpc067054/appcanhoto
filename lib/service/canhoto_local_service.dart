import 'package:hive_flutter/hive_flutter.dart';
import '../models/canhoto.dart';

class CanhotoLocalService {
  final Box _box = Hive.box('canhotos_local');

  bool _mesmoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Carrega a lista de canhotos salvos localmente (somente do dia).
  Future<List<Canhoto>> loadToday() async {
    final raw = _box.get('today');
    if (raw is! List) return [];

    final hoje = DateTime.now();
    return raw
        .map((item) => Canhoto.fromMap(Map<String, dynamic>.from(item)))
        .where((c) => _mesmoDia(c.dataHora, hoje))
        .toList();
  }

  /// Salva a lista local completa preservando o histórico do dia.
  Future<void> saveToday(List<Canhoto> lista) async {
    final hoje = DateTime.now();
    final items = lista.where((c) => _mesmoDia(c.dataHora, hoje)).toList();
    final dedup = <Canhoto>[];

    for (final item in items) {
      final existe = dedup.any((c) {
        if (c.clienteId.isNotEmpty && item.clienteId.isNotEmpty) {
          return c.clienteId == item.clienteId;
        }
        return c.dataHora == item.dataHora &&
            c.idEmpresa == item.idEmpresa &&
            c.numeroNota == item.numeroNota;
      });

      if (!existe) {
        dedup.add(item);
      }
    }

    final serialized = dedup.map((c) => c.toMap()).toList();
    await _box.put('today', serialized);
  }

  /// Limpa todos os canhotos locais do dia (se precisar no futuro).
  Future<void> clear() async {
    await _box.put('today', []);
  }
}