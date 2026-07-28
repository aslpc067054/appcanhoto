import 'dart:typed_data';
import 'dart:convert';

import 'sync_status.dart';

class Canhoto {
  final int? id;
  final String clienteId;
  final int idUsuario;
  final int idEmpresa;
  final String empresaNome;
  final String numeroNota;
  final DateTime dataHora;
  //final String usuarioNome; 
  final Uint8List imagemBytes;
  final SyncStatus status;

  Canhoto({
    required this.id,
    required this.clienteId,
    required this.idUsuario,
    required this.idEmpresa,
    required this.empresaNome,
    required this.numeroNota,
    required this.dataHora,
    //required this.usuarioNome,
    required this.imagemBytes,
    required this.status,
  });

  /// cópia imutável do objeto (usado para atualizar status)
  Canhoto copyWith({
    int? id,
    String? clienteId,
    int? idUsuario,
    int? idEmpresa,
    String? empresaNome,
    String? numeroNota,
    DateTime? dataHora,
    //String? usuarioNome,
    Uint8List? imagemBytes,
    SyncStatus? status,
  }) {
    return Canhoto(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      idUsuario: idUsuario ?? this.idUsuario,
      idEmpresa: idEmpresa ?? this.idEmpresa,
      empresaNome: empresaNome ?? this.empresaNome,
      numeroNota: numeroNota ?? this.numeroNota,
      dataHora: dataHora ?? this.dataHora,
      //usuarioNome: usuarioNome ?? this.usuarioNome,
      imagemBytes: imagemBytes ?? this.imagemBytes,
      status: status ?? this.status,
    );
  }

  /// usado para salvar no Hive
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clienteId': clienteId,
      'idUsuario': idUsuario,
      'idEmpresa': idEmpresa,
      'empresaNome': empresaNome,
      'numeroNota': numeroNota,
      'dataHora': dataHora.toIso8601String(),
      'imagemBase64': imagemBytes.isEmpty ? '' : base64Encode(imagemBytes),
      'status': status.name,
    };
  }

  /// usado ao carregar do Hive
  factory Canhoto.fromMap(Map<String, dynamic> map) {
    final imagemBase64 = map['imagemBase64'];
    final bytes = (imagemBase64 == null ||
            (imagemBase64 is String && imagemBase64.trim().isEmpty))
        ? Uint8List(0)
        : base64Decode(imagemBase64.toString());

    return Canhoto(
      id: map['id'],
      clienteId: map['clienteId']?.toString() ??
          map['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      idUsuario: map['idUsuario'],
      idEmpresa: map['idEmpresa'],
      empresaNome: map['empresaNome'],
      numeroNota: map['numeroNota'],
      dataHora: DateTime.parse(map['dataHora']),
      // usuarioNome: map['UsuarioNome'],
      imagemBytes: bytes,
      status: SyncStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}