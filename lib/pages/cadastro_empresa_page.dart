import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:appcanhoto/core/api_config.dart';

/// InputFormatter para telefone no formato: (99) 99999-9999
class TelefoneInputFormatter extends TextInputFormatter {
  String _onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = _onlyDigits(newValue.text);
    String formatted = '';

    int i = 0;
    if (digits.isNotEmpty) {
      formatted += '(';
      while (i < digits.length && i < 2) {
        formatted += digits[i];
        i++;
      }
      if (digits.length >= 2) formatted += ') ';
    }
    if (digits.length > 2) {
      while (i < digits.length && i < 7) {
        formatted += digits[i];
        i++;
      }
      if (digits.length >= 7) formatted += '-';
    }
    if (digits.length > 7) {
      while (i < digits.length && i < 11) {
        formatted += digits[i];
        i++;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Modelo de Empresa
class Empresa {
  final int id;
  final String nomeFantasia;
  final String razaoSocial;
  final String cidade;
  final String estado;
  final String? rua;
  final String? numero;
  final String? telefone;
  final int status; // 0 = ativo, 1 = inativo

  Empresa({
    required this.id,
    required this.nomeFantasia,
    required this.razaoSocial,
    required this.cidade,
    required this.estado,
    this.rua,
    this.numero,
    this.telefone,
    required this.status,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      nomeFantasia: (json['nomeFantasia'] ?? json['nome_fantasia'] ?? '') as String,
      razaoSocial: (json['razaoSocial'] ?? json['razao_social'] ?? '') as String,
      cidade: (json['cidade'] ?? '') as String,
      estado: (json['estado'] ?? '') as String,
      rua: json['rua']?.toString(),
      numero: json['numero']?.toString(),
      telefone: json['telefone']?.toString(),
      status: json['status'] is int
          ? json['status'] as int
          : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nomeFantasia': nomeFantasia,
      'razaoSocial': razaoSocial,
      'cidade': cidade,
      'estado': estado,
      'rua': rua,
      'numero': numero,
      'telefone': telefone,
      'status': status,
    };
  }

  Empresa copyWith({
    int? id,
    String? nomeFantasia,
    String? razaoSocial,
    String? cidade,
    String? estado,
    String? rua,
    String? numero,
    String? telefone,
    int? status,
  }) {
    return Empresa(
      id: id ?? this.id,
      nomeFantasia: nomeFantasia ?? this.nomeFantasia,
      razaoSocial: razaoSocial ?? this.razaoSocial,
      cidade: cidade ?? this.cidade,
      estado: estado ?? this.estado,
      rua: rua ?? this.rua,
      numero: numero ?? this.numero,
      telefone: telefone ?? this.telefone,
      status: status ?? this.status,
    );
  }
}

class CadastroEmpresaPage extends StatefulWidget {
  const CadastroEmpresaPage({super.key});

  @override
  State<CadastroEmpresaPage> createState() => _CadastroEmpresaPageState();
}

class _CadastroEmpresaPageState extends State<CadastroEmpresaPage> {
  // ====== CONTROLES DO FORM ======
  final _formKey = GlobalKey<FormState>();

  final _nomeFantasiaCtrl = TextEditingController();
  final _razaoSocialCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _ruaCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  String? _estadoSelecionado; // dropdown de UFs

  // status atual do formulário (0 = ativo; 1 = inativo)
  int _statusAtual = 0;

  // Edição: quando != null, estamos editando (PUT); quando null, criação (POST)
  int? _editingId;

  // Lista que alimenta o grid
  List<Empresa> _empresas = [];

  // Estados
  bool _loadingLista = false;
  bool _salvando = false;
  int? _alterandoStatusId;

  // ====== API CONFIG ======
  static const bool _usarApi = true; // mude para true quando a API estiver ativa

  // String get baseUrl {
  //   if (kIsWeb) return 'https://localhost:7245'; // Web → HTTPS do seu perfil
  //   if (defaultTargetPlatform == TargetPlatform.android) {
  //     return 'http://10.0.2.2:5166'; // Android emulador
  //   }
  //   return 'http://localhost:5166'; // iOS simulador / desktop
  // }

  // // >>> ALTERAÇÃO AQUI: fixamos o IP/porta da sua API <<<
  // String get baseUrl {
  //   const host = '192.168.0.191';

  //   // HTTPS (requer certificado válido para o IP configurado no Kestrel)
  //   const httpsPort = 7245;
  //   return 'https://$host:$httpsPort';

  //   // Se preferir usar HTTP durante o dev, descomente abaixo:
  //   // const httpPort = 5166;
  
  //   // return 'http://$host:$httpPort';
  // }   

    String get baseUrl => '${ApiConfig.base}/api'; 

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // UFs do Brasil
  static const List<String> _ufs = [
    'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA',
    'PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO',
  ];

  @override
  void initState() {
    super.initState();
    _carregarEmpresas();
  }

  @override
  void dispose() {
    _nomeFantasiaCtrl.dispose();
    _razaoSocialCtrl.dispose();
    _cidadeCtrl.dispose();
    _ruaCtrl.dispose();
    _numeroCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  // ===========================================================
  // C A R R E G A R   /   S A L V A R   /   A T I V A R | I N A T I V A R
  // ===========================================================

  Future<void> _carregarEmpresas() async {
    setState(() => _loadingLista = true);

    try {
      if (_usarApi) {
        final uri = Uri.parse('$baseUrl/empresas');
        final resp = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));

        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body);
          final List list = body is List ? body : (body['data'] ?? []) as List;
          _empresas = list.map((e) => Empresa.fromJson(e as Map<String, dynamic>)).toList();
        } else {
          _showSnack('Erro ao consultar empresas (${resp.statusCode})');
        }
      } else {
        // (opcional) simulação local
        // _empresas = [
        //   Empresa(
        //     id: 1,
        //     nomeFantasia: 'Express Show',
        //     razaoSocial: 'Express Show LTDA',
        //     cidade: 'Chapecó',
        //     estado: 'SC',
        //     rua: 'Av. Central',
        //     numero: '123',
        //     telefone: '(49) 99999-0000',
        //     status: 0,
        //   ),
        // ];
      }
    } catch (e) {
      _showSnack('Falha ao consultar empresas');
    } finally {
      if (mounted) setState(() => _loadingLista = false);
    }
  }

  Future<void> _salvar() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final nomeFantasia = _nomeFantasiaCtrl.text.trim();
    final razaoSocial = _razaoSocialCtrl.text.trim();
    final cidade = _cidadeCtrl.text.trim();
    final estado = (_estadoSelecionado ?? '').trim();
    final rua = _ruaCtrl.text.trim().isEmpty ? null : _ruaCtrl.text.trim();
    final numero = _numeroCtrl.text.trim().isEmpty ? null : _numeroCtrl.text.trim();
    final telefone = _telefoneCtrl.text.trim().isEmpty ? null : _telefoneCtrl.text.trim();

    final payload = {
      'nomeFantasia': nomeFantasia,
      'razaoSocial': razaoSocial,
      'cidade': cidade,
      'estado': estado,
      'rua': rua,
      'numero': numero,
      'telefone': telefone,
      // No POST/PUT não mudamos status por aqui. Ele começa como 0 (ativo).
      // Se quiser permitir alteração de status no PUT, pode enviar 'status': _statusAtual
    };

    setState(() => _salvando = true);
    try {
      if (_usarApi) {
        http.Response resp;
        if (_editingId == null) {
          final uri = Uri.parse('$baseUrl/empresas');
          resp = await http.post(uri, headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 20));
        } else {
          final uri = Uri.parse('$baseUrl/empresas/$_editingId');
          resp = await http.put(uri, headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 20));
        }

        if (resp.statusCode == 201 || resp.statusCode == 200 || resp.statusCode == 204) {
          _showSnack(_editingId == null ? 'Empresa cadastrada com sucesso.' : 'Empresa atualizada com sucesso.');
          _limparCampos();
          await _carregarEmpresas();
        } else if (resp.statusCode == 400) {
          _showSnack('Dados inválidos: ${resp.body}');
        } else if (resp.statusCode == 409) {
          _showSnack('Conflito: possível duplicidade.');
        } else if (resp.statusCode == 404) {
          _showSnack('Empresa não encontrada (404).');
        } else {
          _showSnack('Erro ao salvar (${resp.statusCode}): ${resp.body}');
        }
      } else {
        if (_editingId == null) {
          final novo = Empresa(
            id: DateTime.now().millisecondsSinceEpoch,
            nomeFantasia: nomeFantasia,
            razaoSocial: razaoSocial,
            cidade: cidade,
            estado: estado,
            rua: rua,
            numero: numero,
            telefone: telefone,
            status: 0, // começa ativo
          );
          _empresas.add(novo);
          _showSnack('Empresa cadastrada (modo local).');
        } else {
          final idx = _empresas.indexWhere((e) => e.id == _editingId);
          if (idx >= 0) {
            _empresas[idx] = _empresas[idx].copyWith(
              nomeFantasia: nomeFantasia,
              razaoSocial: razaoSocial,
              cidade: cidade,
              estado: estado,
              rua: rua,
              numero: numero,
              telefone: telefone,
              // status: _statusAtual, // se quiser alterar pelo form
            );
            _showSnack('Empresa atualizada (modo local).');
          }
        }
        setState(() {});
        _limparCampos();
      }
    } catch (e) {
      _showSnack('Falha de conexão ao salvar.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _alterarStatusEmpresa(Empresa e, int novoStatus) async {
    setState(() => _alterandoStatusId = e.id);
    try {
      if (_usarApi) {
        final uri = Uri.parse('$baseUrl/empresas/${e.id}/status');
        final resp = await http
            .patch(uri, headers: _headers, body: jsonEncode({'status': novoStatus}))
            .timeout(const Duration(seconds: 20));

        if (resp.statusCode == 204) {
          final idx = _empresas.indexWhere((x) => x.id == e.id);
          if (idx >= 0) {
            _empresas[idx] = _empresas[idx].copyWith(status: novoStatus);
            setState(() {});
          }
          _showSnack(novoStatus == 1 ? 'Empresa inativada.' : 'Empresa ativada.');
        } else if (resp.statusCode == 404) {
          _showSnack('Empresa não encontrada (404).');
          await _carregarEmpresas();
        } else if (resp.statusCode == 400) {
          _showSnack('Status inválido.');
        } else {
          _showSnack('Erro ao alterar status (${resp.statusCode}): ${resp.body}');
        }
      } else {
        // modo local
        final idx = _empresas.indexWhere((x) => x.id == e.id);
        if (idx >= 0) {
          _empresas[idx] = _empresas[idx].copyWith(status: novoStatus);
          setState(() {});
        }
        _showSnack(novoStatus == 1 ? 'Empresa inativada (local).' : 'Empresa ativada (local).');
      }
    } catch (ex) {
      _showSnack('Falha ao alterar status.');
    } finally {
      if (mounted) setState(() => _alterandoStatusId = null);
    }
  }

  // ===========================================================
  //   U I   H E L P E R S
  // ===========================================================

  void _editar(Empresa e) {
    setState(() {
      _editingId = e.id;
      _nomeFantasiaCtrl.text = e.nomeFantasia;
      _razaoSocialCtrl.text = e.razaoSocial;
      _cidadeCtrl.text = e.cidade;
      _estadoSelecionado = e.estado.toUpperCase();
      _ruaCtrl.text = e.rua ?? '';
      _numeroCtrl.text = e.numero ?? '';
      _telefoneCtrl.text = e.telefone ?? '';
      _statusAtual = e.status;
    });
    _showSnack('Modo edição: ${e.nomeFantasia}');
  }

  void _limparCampos() {
    _nomeFantasiaCtrl.clear();
    _razaoSocialCtrl.clear();
    _cidadeCtrl.clear();
    _estadoSelecionado = null;
    _ruaCtrl.clear();
    _numeroCtrl.clear();
    _telefoneCtrl.clear();
    _statusAtual = 0;
    setState(() => _editingId = null);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===========================================================
  //                    B U I L D
  // ===========================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget statusChip(int status) => Chip(
          label: Text(status == 0 ? 'ATIVO' : 'INATIVO'),
          backgroundColor: status == 0 ? Colors.green.shade700 : Colors.red.shade700,
          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId == null ? 'Cadastro de Empresa' : 'Editar Empresa'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : null,
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: RefreshIndicator(
        onRefresh: _carregarEmpresas,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ======= CARD FORM =======
            Card(
              color: isDark ? const Color(0xFF121212) : null,
              elevation: isDark ? 0 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // Linha: Nome fantasia + status label
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nomeFantasiaCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nome fantasia',
                                prefixIcon: Icon(Icons.apartment),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome fantasia' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          statusChip(_statusAtual),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Razão Social (obrigatório)
                      TextFormField(
                        controller: _razaoSocialCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Razão social',
                          prefixIcon: Icon(Icons.business_center),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a razão social' : null,
                      ),
                      const SizedBox(height: 12),

                      // Cidade (obrigatório)
                      TextFormField(
                        controller: _cidadeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cidade',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a cidade' : null,
                      ),
                      const SizedBox(height: 12),

                      // UF com Dropdown
                      DropdownButtonFormField<String>(
                        value: _estadoSelecionado,
                        items: _ufs
                            .map((uf) => DropdownMenuItem(
                                  value: uf,
                                  child: Text(uf),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _estadoSelecionado = val),
                        decoration: const InputDecoration(
                          labelText: 'Estado (UF)',
                          prefixIcon: Icon(Icons.flag),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Selecione a UF' : null,
                      ),
                      const SizedBox(height: 12),

                      // Rua (opcional)
                      TextFormField(
                        controller: _ruaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Rua (opcional)',
                          prefixIcon: Icon(Icons.signpost),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Número (opcional)
                      TextFormField(
                        controller: _numeroCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Número (opcional)',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Telefone (opcional) com máscara
                      TextFormField(
                        controller: _telefoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [TelefoneInputFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Telefone (opcional)',
                          hintText: '(49) 99999-0000',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              icon: _salvando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_editingId == null ? 'Salvar' : 'Atualizar'),
                              onPressed: _salvando
                                  ? null
                                  : () {
                                      final valido = _formKey.currentState?.validate() ?? false;
                                      if (valido) _salvar();
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Limpar'),
                              onPressed: _salvando ? null : _limparCampos,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ======= CARD GRID =======
            Card(
              color: isDark ? const Color(0xFF121212) : null,
              elevation: isDark ? 0 : 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _loadingLista
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _buildDataTable(context, statusChip),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(BuildContext context, Widget Function(int) statusChip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_empresas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('Nenhuma empresa cadastrada.')),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 44,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        columnSpacing: 24,
        columns: const [
          DataColumn(label: Text('Nome fantasia')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Razão social')),
          DataColumn(label: Text('Cidade')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Rua')),
          DataColumn(label: Text('Número')),
          DataColumn(label: Text('Telefone')),
          DataColumn(label: Text('Ações')),
        ],
        rows: _empresas.map((e) {
          final alterando = _alterandoStatusId == e.id;
          final ehAtivo = e.status == 0;

          return DataRow(
            cells: [
              DataCell(Text(e.nomeFantasia)),
              DataCell(statusChip(e.status)),
              DataCell(Text(e.razaoSocial)),
              DataCell(Text(e.cidade)),
              DataCell(Text(e.estado.toUpperCase())),
              DataCell(Text(e.rua ?? '')),
              DataCell(Text(e.numero ?? '')),
              DataCell(Text(e.telefone ?? '')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDITAR
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit),
                      color: isDark ? Colors.white : Colors.blueGrey,
                      onPressed: () => _editar(e),
                    ),
                    const SizedBox(width: 4),
                    // INATIVAR / ATIVAR
                    alterando
                        ? const SizedBox(
                            width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            tooltip: ehAtivo ? 'Inativar' : 'Ativar',
                            icon: Icon(ehAtivo ? Icons.block : Icons.check_circle_outline),
                            color: ehAtivo ? Colors.redAccent : Colors.green,
                            onPressed: () => _alterarStatusEmpresa(e, ehAtivo ? 1 : 0),
                          ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}