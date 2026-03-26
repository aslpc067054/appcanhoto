class Empresa {
  final int id;
  final String nomeFantasia;
  final int status;

  Empresa({
    required this.id,
    required this.nomeFantasia,
    required this.status,
  });

  factory Empresa.fromJson(Map<String, dynamic> j) {
    return Empresa(
      // ✅ ID (int ou string)
      id: j['id'] is int
          ? j['id']
          : int.tryParse(j['id'].toString()) ?? 0,

      // ✅ nomeFantasia (string segura)
      nomeFantasia: j['nomeFantasia']?.toString() ?? '',

      // ✅ Status (0 = ativo, 1 = inativo)
      status: j['status'] is int ? j['status'] : int.tryParse(j['status'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nomeFantasia': nomeFantasia,
        'status': status,
      };
}