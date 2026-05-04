import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../models/empresa.dart';
import '../models/canhoto.dart';
import '../models/sync_status.dart';

import '../service/canhoto_local_service.dart';
import '../service/offline_queue_service.dart';
import '../service/canhoto_remote_service.dart';
import '../service/connectivity_service.dart';
import '../service/sync_service.dart';

import '../core/api_config.dart';

class CanhotoPage extends StatefulWidget {
  final int idUsuario;
  final String usuarioNome;

  const CanhotoPage({
    super.key,
    required this.idUsuario,
    required this.usuarioNome,
  });

  @override
  State<CanhotoPage> createState() => _CanhotoPageState();
}

class _CanhotoPageState extends State<CanhotoPage> {
  late final CanhotoLocalService local;
  late final OfflineQueueService queue;
  late final CanhotoRemoteService remote;
  late final ConnectivityService conn;
  late final SyncService syncer;

  List<Empresa> empresas = [];
  List<Canhoto> listaHoje = [];

  Empresa? empresaSelecionada;
  Uint8List? imagemAtual;

  final notaCtrl = TextEditingController();
  final empresaCtrl = TextEditingController();

  bool carregandoEmpresas = false;
  bool salvando = false;
  bool online = true;

  StreamSubscription? _connSub;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();

    local = CanhotoLocalService();
    queue = OfflineQueueService();
    conn = ConnectivityService();
    remote = CanhotoRemoteService("${ApiConfig.base}/api");
    syncer = SyncService(queue: queue, local: local, remote: remote, conn: conn);

    _init();
    _monitorarConexao();
  }

  Future<void> _init() async {
    await _carregarEmpresas();
    await _carregarHoje();
  }

  // =========================================================
  // MONITORAR CONEXÃO + SYNC + LIMPEZA
  // =========================================================
  void _monitorarConexao() {
    _connSub = conn.onChange.listen((_) async {
      final ok = await conn.hasInternet();
      if (!mounted) return;
      setState(() => online = ok);

      if (!ok) return;

      // evita rodar sync em paralelo se o onChange disparar várias vezes
      if (_syncing) return;
      _syncing = true;

      try {
        await syncer.sync();

        // recarrega para pegar os status atualizados (synced/pending/erro)
        await _carregarHoje();

        // LIMPEZA: remove sincronizados do storage para não acumular no iOS
        await _limparSincronizados();

        // recarrega de novo (opcional, mas garante lista atualizada)
        await _carregarHoje();
      } catch (e) {
        debugPrint("ERRO SYNC (monitor): $e");
      } finally {
        _syncing = false;
      }
    });
  }

  // =========================================================
  // LIMPEZA AUTOMÁTICA (REMOVE ITENS SINCRONIZADOS)
  // =========================================================
  Future<void> _limparSincronizados() async {
    final hoje = DateTime.now();

    listaHoje.removeWhere((c) {
      final mesmaData =
          c.dataHora.year == hoje.year &&
          c.dataHora.month == hoje.month &&
          c.dataHora.day == hoje.day;

      // REMOVE somente:
      // - já sincronizados
      // - que NÃO são do dia atual
      return c.status == SyncStatus.synced && !mesmaData;
    });

    await local.saveToday(listaHoje);

    if (!mounted) return;
    setState(() {});
  }
    // =========================================================
  // CARREGAR EMPRESAS
  // =========================================================
  Future<void> _carregarEmpresas() async {
    if (!mounted) return;
    setState(() => carregandoEmpresas = true);

    try {
      final uri = Uri.parse("${ApiConfig.base}/api/empresas");
      final resp = await http.get(uri);

      if (resp.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(resp.body);

        final list = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        empresas = list.map((e) => Empresa.fromJson(e)).toList();

        // Apenas ativas
        empresas = empresas.where((e) => e.status == 0).toList();

        debugPrint("EMPRESAS CARREGADAS: ${empresas.length}");
      } else {
        throw Exception("HTTP ${resp.statusCode}");
      }
    } catch (e) {
      debugPrint("ERRO EMPRESAS: $e");
      _msg("Erro ao carregar empresas.");
    }

    if (!mounted) return;
    setState(() => carregandoEmpresas = false);
  }

  // =========================================================
  // CARREGAR CANHOTOS DO DIA
  // =========================================================
  Future<void> _carregarHoje() async {
    listaHoje = await local.loadToday();
    if (!mounted) return;
    setState(() {});
  }

  // =========================================================
  // FOTO (CÂMERA)
  // =========================================================
  Future<void> _tirarFoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (file != null) {
        imagemAtual = await file.readAsBytes();
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      debugPrint("ERRO CAMERA: $e");
      _msg("Erro ao abrir a câmera.");
    }
  }

  // =========================================================
  // FOTO (GALERIA)
  // =========================================================
  Future<void> _buscarImagemInterna() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (file != null) {
        imagemAtual = await file.readAsBytes();
        if (!mounted) return;
        setState(() {});
      }
    } catch (e) {
      debugPrint("ERRO GALERIA: $e");
      _msg("Erro ao abrir a galeria.");
    }
  }

  // =========================================================
  // SALVAR (OFFLINE-FIRST) + SYNC + LIMPEZA
  // =========================================================
  Future<void> _salvar() async {
    if (empresaSelecionada == null) {
      _msg("Selecione a empresa.");
      return;
    }
    if (notaCtrl.text.trim().isEmpty) {
      _msg("Digite a nota.");
      return;
    }
    if (imagemAtual == null) {
      _msg("Selecione a imagem.");
      return;
    }

    if (!mounted) return;
    setState(() => salvando = true);

    try {
      final novo = Canhoto(
        id: null,
        idUsuario: widget.idUsuario,
        idEmpresa: empresaSelecionada!.id,
        empresaNome: empresaSelecionada!.nomeFantasia,
        numeroNota: notaCtrl.text.trim(),
        dataHora: DateTime.now(),
        imagemBytes: imagemAtual!,
        status: SyncStatus.pending,
      );

      listaHoje.insert(0, novo);
      await local.saveToday(listaHoje);
      await queue.add(novo);

      _limpar();
      if (!mounted) return;
      setState(() => salvando = false);

      _msg("Salvo localmente. Será sincronizado.");

      // Se online, sincroniza e limpa automaticamente
      if (online) {
        if (_syncing) return;
        _syncing = true;

        try {
          await syncer.sync();

          // recarrega para pegar status atualizado (synced/pending/erro)
          await _carregarHoje();

          // LIMPEZA: remove sincronizados do storage para não acumular no iOS
          await _limparSincronizados();

          // recarrega lista final
          await _carregarHoje();
        } catch (e) {
          debugPrint("ERRO SYNC (salvar): $e");
        } finally {
          _syncing = false;
        }
      }
    } catch (e) {
      debugPrint("ERRO SALVAR: $e");
      if (!mounted) return;
      setState(() => salvando = false);
      _msg("Erro ao salvar.");
    }
  }

  void _limpar() {
    // empresaSelecionada = null; // opcional
    notaCtrl.clear();
    imagemAtual = null;
    if (!mounted) return;
    setState(() {});
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Canhotos • ${widget.usuarioNome}"),
        centerTitle: true,
        actions: [
          Chip(
            backgroundColor: online ? Colors.green : Colors.red,
            label: Text(
              online ? "ONLINE" : "OFFLINE",
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregarHoje,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _form(),
            const SizedBox(height: 20),
            _lista(),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // FORM
  // =========================================================
  Widget _form() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            carregandoEmpresas
                ? const LinearProgressIndicator()
                : Autocomplete<Empresa>(
                    displayStringForOption: (e) => e.nomeFantasia,
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      controller.text = empresaCtrl.text;

                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: "Empresa",
                          prefixIcon: Icon(Icons.apartment),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          empresaCtrl.text = value;
                          empresaSelecionada = null;
                        },
                      );
                    },
                    optionsBuilder: (TextEditingValue value) {
                      if (value.text.isEmpty) return empresas;
                      return empresas.where((e) => e.nomeFantasia
                          .toLowerCase()
                          .startsWith(value.text.toLowerCase()));
                    },
                    onSelected: (empresa) {
                      empresaSelecionada = empresa;
                      empresaCtrl.text = empresa.nomeFantasia;
                      if (!mounted) return;
                      setState(() {});
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 300,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final empresa = options.elementAt(index);
                                return ListTile(
                                  title: Text(empresa.nomeFantasia),
                                  onTap: () {
                                    onSelected(empresa);
                                    FocusScope.of(context).unfocus();
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 20),
            TextField(
              controller: notaCtrl,
              decoration: const InputDecoration(
                labelText: "Número da Nota",
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: imagemAtual == null
                        ? const Center(child: Text("Nenhuma imagem"))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              imagemAtual!,
                              fit: BoxFit.cover,
                              // diminui o custo do decode na UI
                              cacheWidth: 900,
                              cacheHeight: 900,
                              filterQuality: FilterQuality.low,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    SizedBox(
                      width: 110,
                      child: FilledButton(
                        onPressed: _tirarFoto,
                        child: const Text("Foto"),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 110,
                      child: FilledButton(
                        onPressed: _buscarImagemInterna,
                        child: const Text("Interna"),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 110,
                      child: OutlinedButton(
                        onPressed: () => setState(() => imagemAtual = null),
                        child: const Text("Limpar"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: salvando ? null : _salvar,
                icon: salvando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(salvando ? "Salvando..." : "Salvar"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // LISTAGEM (OTIMIZADA PARA iOS: ListView.builder + thumbnails)
  // =========================================================
  Widget _lista() {
    if (listaHoje.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text("Nenhum canhoto salvo hoje.")),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listaHoje.length,
      itemBuilder: (context, index) {
        final c = listaHoje[index];

        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 60,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  c.imagemBytes,
                  fit: BoxFit.cover,
                  // MUITO importante no iOS Safari: evita decode gigante
                  cacheWidth: 120,
                  cacheHeight: 120,
                  filterQuality: FilterQuality.low,
                ),
              ),
            ),
            title: Text("${c.empresaNome} — NF ${c.numeroNota}"),
            subtitle: Text(
              "${c.dataHora.day}/${c.dataHora.month}/${c.dataHora.year} "
              "${c.dataHora.hour}:${c.dataHora.minute.toString().padLeft(2, '0')}",
            ),
            trailing: Chip(
              label: Text(
                c.status == SyncStatus.synced
                    ? "SINCRONIZADO"
                    : c.status == SyncStatus.pending
                        ? "PENDENTE"
                        : "ERRO",
              ),
              backgroundColor: c.status == SyncStatus.synced
                  ? Colors.green
                  : c.status == SyncStatus.pending
                      ? Colors.orange
                      : Colors.red,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _connSub?.cancel();
    notaCtrl.dispose();
    empresaCtrl.dispose();
    super.dispose();
  }
}