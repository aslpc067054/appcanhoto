import '../models/canhoto.dart';
import '../models/sync_status.dart';

import 'canhoto_local_service.dart';
import 'offline_queue_service.dart';
import 'canhoto_remote_service.dart';
import 'connectivity_service.dart';

class SyncService {
  final OfflineQueueService queue;
  final CanhotoLocalService local;
  final CanhotoRemoteService remote;
  final ConnectivityService conn;

  SyncService({
    required this.queue,
    required this.local,
    required this.remote,
    required this.conn,
  });

  /// ✅ Tenta sincronizar toda a fila
  Future<void> sync() async {
    // Garante conexão real
    if (!await conn.hasInternet()) return;

    final fila = queue.getQueue();
    if (fila.isEmpty) return;

    final listaHoje = await local.loadToday();

    for (final item in fila) {
      try {
        // ✅ Tentando enviar
        final novoId = await remote.enviar(item);

        if (novoId != null) {
          // ✅ Sincronizado com sucesso!
          final atualizado = item.copyWith(
            id: novoId,
            status: SyncStatus.synced,
          );

          // Atualiza lista diária
          final idx = listaHoje.indexWhere(
            (c) => c.dataHora == item.dataHora,
          );

          if (idx >= 0) listaHoje[idx] = atualizado;

          // Remove da fila
          await queue.remove(item);
        } else {
          _marcarErro(item, listaHoje);
        }
      } catch (_) {
        _marcarErro(item, listaHoje);
      }
    }

    // ✅ Salva lista atualizada
    await local.saveToday(listaHoje);
  }

  /// ✅ Marca um item como falha na sincronização
  void _marcarErro(Canhoto item, List<Canhoto> listaHoje) {
    final erro = item.copyWith(status: SyncStatus.error);

    final idx = listaHoje.indexWhere(
      (c) => c.dataHora == item.dataHora,
    );

    if (idx >= 0) listaHoje[idx] = erro;
  }
}