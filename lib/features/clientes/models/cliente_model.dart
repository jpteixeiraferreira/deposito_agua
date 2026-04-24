class Cliente {
  final String id;
  final String nome;
  final String telefone;
  final String endereco;
  final String referencia;
  final String cpfCnpj;
  final bool ativo;

  Cliente({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.endereco,
    required this.referencia,
    required this.cpfCnpj,
    required this.ativo,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: (map['id'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      telefone: (map['telefone'] ?? '').toString(),
      endereco: (map['endereco'] ?? '').toString(),
      referencia: (map['referencia'] ?? '').toString(),
      cpfCnpj: (map['cpf_cnpj'] ?? '').toString(),
      ativo: map['ativo'] ?? true,
    );
  }
}
