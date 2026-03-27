import 'package:hive_flutter/hive_flutter.dart';
import '../models/canhoto.dart';

class CanhotoLocalService {
  final Box _box = Hive.box('canhotos_local');

  /// ✅ Carrega a lista de canhotos salvos localmente (somente do dia).
  Future<List<Canhoto>> loadToday() async {
    final raw = _box.get('today') as List?;
    if (raw == null) return [];

    return raw
        .map((item) => Canhoto.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// ✅ Salva a lista local completa.
  Future<void> saveToday(List<Canhoto> lista) async {
    final serialized =
        lista.map((c) => c.toMap()).toList();

    await _box.put('today', serialized);
  }

  /// ✅ Limpa todos os canhotos locais do dia (se precisar no futuro).
  Future<void> clear() async {
    await _box.put('today', []);
  }
}