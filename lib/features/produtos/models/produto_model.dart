class Produto {
  final String id;
  final String codigo;
  final String descricao;
  final double precoCusto;
  final double precoVenda;
  final double estoqueAtual;

  Produto({
    required this.id,
    required this.codigo,
    required this.descricao,
    required this.precoCusto,
    required this.precoVenda,
    required this.estoqueAtual,
  });

  factory Produto.fromMap(Map<String, dynamic> map) {
    return Produto(
      id: (map['id'] ?? '').toString(),
      codigo: (map['codigo'] ?? '').toString(),
      descricao: (map['descricao'] ?? '').toString(),
      precoCusto: double.tryParse(map['preco_custo'].toString()) ?? 0,
      precoVenda: double.tryParse(map['preco_venda'].toString()) ?? 0,
      estoqueAtual: double.tryParse(map['estoque_atual'].toString()) ?? 0,
    );
  }
}
