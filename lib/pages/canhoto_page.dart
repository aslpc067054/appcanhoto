import 'dart:convert';
import 'dart:typed_data';

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

  bool carregandoEmpresas = false;
  bool salvando = false;
  bool online = true;

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

  void _monitorarConexao() {
    conn.onChange.listen((_) async {
      final ok = await conn.hasInternet();
      setState(() => online = ok);

      if (ok) {
        await syncer.sync();
        await _carregarHoje();
      }
    });
  }

  // =========================================================
  // CARREGAR EMPRESAS (SEGURA PARA FLUTTER WEB)
  // =========================================================
  Future<void> _carregarEmpresas() async {
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

        print("EMPRESAS CARREGADAS: ${empresas.length}");
      } else {
        throw Exception("HTTP ${resp.statusCode}");
      }
    } catch (e) {
      print("ERRO EMPRESAS: $e");
      _msg("Erro ao carregar empresas.");
    }

    setState(() => carregandoEmpresas = false);
  }

  // =========================================================
  // CARREGAR CANHOTOS DO DIA
  // =========================================================
  Future<void> _carregarHoje() async {
    listaHoje = await local.loadToday();
    setState(() {});
  }

  // =========================================================
  // FOTO
  // =========================================================
  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );

    if (file != null) {
      imagemAtual = await file.readAsBytes();
      setState(() {});
    }
  }

  // =========================================================
  // SALVAR (OFFLINE-FIRST)
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

    setState(() => salvando = true);

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
    setState(() => salvando = false);

    _msg("Salvo localmente. Será sincronizado.");

    if (online) {
      syncer.sync().then((_) => _carregarHoje());
    }
  }

  void _limpar() {
    empresaSelecionada = null;
    notaCtrl.clear();
    imagemAtual = null;
    setState(() {});
  }

  void _msg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

//buscar imagem interna
  Future<void> _buscarImagemInterna() async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );

  if (file != null) {
    imagemAtual = await file.readAsBytes();
    setState(() {});
  }
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
  // FORM (COM DROPDOWNSEARCH 6.x)
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
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Empresa",
                      prefixIcon: Icon(Icons.apartment),
                      border: OutlineInputBorder(),
                    ),

                    onTap: () {
                      // Mostra lista completa ao clicar
                      controller.text = "";
                      focusNode.requestFocus();
                    },
                  );
                },

                optionsBuilder: (TextEditingValue value) {
                  if (value.text.isEmpty) {
                    // Lista completa se não digitou nada
                    return empresas;
                  }

                  // Filtra conforme digita
                  return empresas.where((e) =>
                      e.nomeFantasia
                          .toLowerCase()
                          .startsWith(value.text.toLowerCase()));
                },

                onSelected: (empresa) {
                  empresaSelecionada = empresa;
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
                                FocusScope.of(context).unfocus(); // fecha dropdown
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
                          child: Image.memory(imagemAtual!, fit: BoxFit.cover),
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
  // LISTAGEM
  // =========================================================
  Widget _lista() {
    if (listaHoje.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text("Nenhum canhoto salvo hoje.")),
      );
    }

    return Column(
      children: listaHoje.map((c) {
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(c.imagemBytes, fit: BoxFit.cover),
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
      }).toList(),
    );
  }
}