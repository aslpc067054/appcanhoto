import 'package:hive_flutter/hive_flutter.dart';
import '../models/canhoto.dart';

class OfflineQueueService {
  final Box _box = Hive.box('offline_queue');

  /// ✅ Retorna toda a fila offline (pendentes + erro)
  List<Canhoto> getQueue() {
    final raw = _box.get('queue') as List?;
    if (raw == null) return [];

    return raw
        .map((item) => Canhoto.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// ✅ Adiciona um item à fila
  Future<void> add(Canhoto c) async {
    final q = getQueue();
    q.add(c);

    await _box.put(
      'queue',
      q.map((i) => i.toMap()).toList(),
    );
  }

  /// ✅ Remove um item EXATO da fila (identificado pela dataHora)
  Future<void> remove(Canhoto c) async {
    final q = getQueue()
      ..removeWhere((i) => i.dataHora == c.dataHora);

    await _box.put(
      'queue',
      q.map((i) => i.toMap()).toList(),
    );
  }

  /// ✅ Substitui toda a fila (quando necessário)
  Future<void> saveAll(List<Canhoto> fila) async {
    await _box.put(
      'queue',
      fila.map((i) => i.toMap()).toList(),
    );
  }

  /// ✅ Limpa fila inteira (não usado agora, mas útil para o futuro)
  Future<void> clear() async {
    await _box.put('queue', []);
  }
}