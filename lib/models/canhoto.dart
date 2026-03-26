import 'dart:typed_data';
import 'dart:convert';

import 'sync_status.dart';

class Canhoto {
  final int? id;
  final int idUsuario;
  final int idEmpresa;
  final String empresaNome;
  final String numeroNota;
  final DateTime dataHora;
  final Uint8List imagemBytes;
  final SyncStatus status;

  Canhoto({
    required this.id,
    required this.idUsuario,
    required this.idEmpresa,
    required this.empresaNome,
    required this.numeroNota,
    required this.dataHora,
    required this.imagemBytes,
    required this.status,
  });

  /// ✅ cópia imutável do objeto (usado para atualizar status)
  Canhoto copyWith({
    int? id,
    int? idUsuario,
    int? idEmpresa,
    String? empresaNome,
    String? numeroNota,
    DateTime? dataHora,
    Uint8List? imagemBytes,
    SyncStatus? status,
  }) {
    return Canhoto(
      id: id ?? this.id,
      idUsuario: idUsuario ?? this.idUsuario,
      idEmpresa: idEmpresa ?? this.idEmpresa,
      empresaNome: empresaNome ?? this.empresaNome,
      numeroNota: numeroNota ?? this.numeroNota,
      dataHora: dataHora ?? this.dataHora,
      imagemBytes: imagemBytes ?? this.imagemBytes,
      status: status ?? this.status,
    );
  }

  /// ✅ usado para salvar no Hive
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'idUsuario': idUsuario,
      'idEmpresa': idEmpresa,
      'empresaNome': empresaNome,
      'numeroNota': numeroNota,
      'dataHora': dataHora.toIso8601String(),
      'imagemBase64': base64Encode(imagemBytes),
      'status': status.name,
    };
  }

  /// ✅ usado ao carregar do Hive
  factory Canhoto.fromMap(Map<String, dynamic> map) {
    return Canhoto(
      id: map['id'],
      idUsuario: map['idUsuario'],
      idEmpresa: map['idEmpresa'],
      empresaNome: map['empresaNome'],
      numeroNota: map['numeroNota'],
      dataHora: DateTime.parse(map['dataHora']),
      imagemBytes: base64Decode(map['imagemBase64']),
      status: SyncStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }
}