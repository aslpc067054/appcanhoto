import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:appcanhoto/core/api_config.dart';

class ApiTerceiroEmpresa {
  final int id;
  final String nomeFantasia;

  ApiTerceiroEmpresa({required this.id, required this.nomeFantasia});

  factory ApiTerceiroEmpresa.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['Id'] ?? json['empresaId'] ?? json['empresa_id'];
    final nome = json['nomeFantasia'] ?? json['nome_fantasia'] ?? json['NomeFantasia'] ?? '';

    return ApiTerceiroEmpresa(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      nomeFantasia: nome.toString(),
    );
  }
}

class ApiTerceiroRegistro {
  final int id;
  final int empresaId;
  final int status;
  final String token;
  final String nomeFantasia;

  ApiTerceiroRegistro({
    required this.id,
    required this.empresaId,
    required this.status,
    required this.token,
    required this.nomeFantasia,
  });

  factory ApiTerceiroRegistro.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['Id'];
    final rawEmpresaId = json['idEmpresa'] ??
        json['IdEmpresa'] ??
        json['empresaId'] ??
        json['EmpresaId'] ??
        json['id_empresa'] ??
        json['empresa_id'];

    final nome = json['nomeFantasia'] ??
        json['nome_fantasia'] ??
        json['NomeFantasia'] ??
        json['empresaNome'] ??
        json['empresa_nome'] ??
        json['empresa']?['nomeFantasia'] ??
        json['empresa']?['NomeFantasia'] ??
        '';

    return ApiTerceiroRegistro(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      empresaId: rawEmpresaId is int
          ? rawEmpresaId
          : int.tryParse(rawEmpresaId?.toString() ?? '') ?? 0,
      status: json['status'] is int
          ? json['status'] as int
          : int.tryParse(json['status']?.toString() ?? '') ?? 0,
      token: (json['token'] ?? json['Token'] ?? '').toString(),
      nomeFantasia: nome.toString(),
    );
  }
}

class ApiTerceiroPage extends StatefulWidget {
  const ApiTerceiroPage({super.key});

  @override
  State<ApiTerceiroPage> createState() => _ApiTerceiroPageState();
}

class _ApiTerceiroPageState extends State<ApiTerceiroPage> {
  final _formKey = GlobalKey<FormState>();

  List<ApiTerceiroEmpresa> _empresas = [];
  List<ApiTerceiroRegistro> _registros = [];
  final Map<int, String> _nomeEmpresasPorId = {};

  int? _empresaSelecionadaId;
  int _statusSelecionado = 1; // 1 = ativo, 0 = inativo
  int? _editandoId;
  int? _linhaSelecionadaId;

  bool _carregandoEmpresas = false;
  bool _carregandoRegistros = false;
  bool _salvando = false;

  String get _baseUrl => '${ApiConfig.base}/api';

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _carregarEmpresas();
    _carregarRegistros();
  }

  Future<void> _carregarEmpresas() async {
    setState(() => _carregandoEmpresas = true);

    try {
      final resp = await _getComFallback(['$_baseUrl/empresas'])
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        _showSnack('Erro ao carregar clientes (${resp.statusCode}).');
        return;
      }

      final data = jsonDecode(resp.body);
      final list = data is List ? data : (data['data'] ?? []);

      final empresas = List<Map<String, dynamic>>.from(list)
          .map(ApiTerceiroEmpresa.fromJson)
          .where((empresa) => empresa.id > 0)
          .toList()
        ..sort((a, b) => a.nomeFantasia.compareTo(b.nomeFantasia));

      if (!mounted) return;
      setState(() {
        _empresas = empresas;
        _nomeEmpresasPorId.clear();
        for (final empresa in empresas) {
          _nomeEmpresasPorId[empresa.id] = empresa.nomeFantasia;
        }
      });
    } catch (e) {
      if (mounted) {
        _showSnack('Falha ao carregar clientes. Verifique a API.');
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoEmpresas = false);
      }
    }
  }

  Future<void> _carregarRegistros() async {
    setState(() => _carregandoRegistros = true);

    try {
      final resp = await _getComFallback(['$_baseUrl/apiterceiro', '$_baseUrl/terceiro'])
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        _showSnack('Erro ao carregar cadastros (${resp.statusCode}).');
        return;
      }

      final data = jsonDecode(resp.body);
      final list = data is List ? data : (data['data'] ?? []);

      final registros = List<Map<String, dynamic>>.from(list)
          .map(ApiTerceiroRegistro.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _registros = registros;
      });
    } catch (e) {
      if (mounted) {
        _showSnack('Falha ao carregar os acessos da API.');
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoRegistros = false);
      }
    }
  }

  Future<void> _salvar() async {
    if (_empresaSelecionadaId == null) {
      _showSnack('Selecione um cliente.');
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      final jaExiste = _registros.any(
        (registro) => registro.empresaId == _empresaSelecionadaId && registro.id != _editandoId,
      );

      if (jaExiste) {
        _showSnack('Este cliente já está cadastrado para acesso à API.');
        return;
      }

      final token = _gerarToken();
      final payload = {
        'empresa_id': _empresaSelecionadaId,
        'token': token,
        'status': _statusSelecionado,
      };

      setState(() => _salvando = true);

      try {
        final endpointBase = '$_baseUrl/apiterceiro';
        final endpointAlternativo = '$_baseUrl/terceiro';
        final url = _editandoId == null
            ? endpointBase
            : '$endpointBase/$_editandoId';
        final urlAlternativo = _editandoId == null
            ? endpointAlternativo
            : '$endpointAlternativo/$_editandoId';

        final response = await _requestComFallback(
          url,
          urlAlternativo,
          method: _editandoId == null ? 'POST' : 'PUT',
          body: payload,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (mounted) {
            _showSnack(_editandoId == null ? 'Cadastro salvo com sucesso.' : 'Cadastro atualizado com sucesso.');
          }
          _limparFormulario();
          await _carregarRegistros();
        } else if (response.statusCode == 409) {
          _showSnack('Este cliente já está cadastrado.');
        } else {
          _showSnack('Erro ao salvar (${response.statusCode}).');
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Falha ao salvar o cadastro da API.');
        }
      } finally {
        if (mounted) {
          setState(() => _salvando = false);
        }
      }
    }
  }

  void _limparFormulario() {
    setState(() {
      _empresaSelecionadaId = null;
      _statusSelecionado = 1;
      _editandoId = null;
      _linhaSelecionadaId = null;
    });
  }

  void _carregarRegistroParaEdicao(ApiTerceiroRegistro registro) {
    setState(() {
      _editandoId = registro.id;
      _linhaSelecionadaId = registro.id;
      _empresaSelecionadaId = registro.empresaId;
      _statusSelecionado = registro.status == 0 ? 0 : 1;
    });

    _showSnack('Registro carregado para edição.');
  }

  String _gerarToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final value = List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();
    return value;
  }

  Future<http.Response> _requestComFallback(
    String primaryUrl,
    String fallbackUrl, {
    required String method,
    required Map<String, dynamic> body,
  }) async {
    final urls = [primaryUrl, fallbackUrl];

    for (final url in urls) {
      final response = await _executeRequest(url, method: method, body: body);
      if (response.statusCode == 404 || response.statusCode == 405) {
        continue;
      }
      return response;
    }

    final last = await _executeRequest(primaryUrl, method: method, body: body);
    return last;
  }

  Future<http.Response> _executeRequest(
    String url, {
    required String method,
    required Map<String, dynamic> body,
  }) async {
    final encoded = jsonEncode(body);

    switch (method) {
      case 'POST':
        return http.post(Uri.parse(url), headers: _headers, body: encoded)
            .timeout(const Duration(seconds: 20));
      case 'PUT':
        return http.put(Uri.parse(url), headers: _headers, body: encoded)
            .timeout(const Duration(seconds: 20));
      default:
        return http.get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 20));
    }
  }

  Future<http.Response> _getComFallback(List<String> urls) async {
    http.Response? lastResponse;

    for (final url in urls) {
      try {
        final resp = await http.get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 20));
        lastResponse = resp;
        if (resp.statusCode == 200 || resp.statusCode == 201) {
          return resp;
        }
      } catch (_) {
        continue;
      }
    }

    return lastResponse ?? http.Response('Erro', 500);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copiarToken(String token) async {
    if (token.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: token));
    if (mounted) {
      _showSnack('Token copiado para a área de transferência.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de acesso a API'),
        centerTitle: true,
        backgroundColor: isDark ? Colors.black : null,
      ),
      backgroundColor: isDark ? Colors.black : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121212) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cadastro do acesso',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_carregandoEmpresas)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(),
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _empresaSelecionadaId,
                                  decoration: const InputDecoration(
                                    labelText: 'Cliente',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _empresas.map((empresa) {
                                    return DropdownMenuItem<int>(
                                      value: empresa.id,
                                      child: Text(empresa.nomeFantasia),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() => _empresaSelecionadaId = value);
                                  },
                                  validator: (value) =>
                                      value == null ? 'Selecione um cliente.' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _statusSelecionado,
                                  decoration: const InputDecoration(
                                    labelText: 'Status',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem<int>(
                                      value: 1,
                                      child: Text('Ativo'),
                                    ),
                                    DropdownMenuItem<int>(
                                      value: 0,
                                      child: Text('Inativo'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _statusSelecionado = value);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 180,
                            child: FilledButton.icon(
                              onPressed: _salvando ? null : _salvar,
                              icon: const Icon(Icons.save),
                              label: Text(_editandoId == null ? 'Salvar' : 'Atualizar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Cadastros existentes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_carregandoRegistros)
                      const Center(child: CircularProgressIndicator())
                    else if (_registros.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121212) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          'Nenhum acesso cadastrado.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 900),
                          child: DataTable(
                            showCheckboxColumn: false,
                            columns: const [
                              DataColumn(label: Text('Nome Fantasia')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Token')),
                              DataColumn(label: Text('Copiar')),
                              DataColumn(label: Text('Alterar')),
                            ],
                            rows: _registros.map((registro) {
                              final nome = (registro.nomeFantasia.isNotEmpty
                                      ? registro.nomeFantasia
                                      : (_nomeEmpresasPorId[registro.empresaId] ?? 'Empresa #${registro.empresaId}'))
                                  .trim();

                              return DataRow(
                                selected: _linhaSelecionadaId == registro.id,
                                onSelectChanged: (_) => _carregarRegistroParaEdicao(registro),
                                cells: [
                                  DataCell(Text(nome.isEmpty ? 'Empresa #${registro.empresaId}' : nome)),
                                  DataCell(Text(registro.status == 1 ? 'Ativo' : 'Inativo')),
                                  DataCell(
                                    SizedBox(
                                      width: 180,
                                      child: Text(
                                        registro.token,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      tooltip: 'Copiar token',
                                      onPressed: () => _copiarToken(registro.token),
                                      icon: const Icon(Icons.copy_all_rounded),
                                    ),
                                  ),
                                  DataCell(
                                    TextButton(
                                      onPressed: () => _carregarRegistroParaEdicao(registro),
                                      child: const Text('Alterar'),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
