import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/produto_model.dart';

class ProdutoRepository {
  final supabase = Supabase.instance.client;

  Future<List<Produto>> buscarTodos() async {
    final response = await supabase
        .from('produtos')
        .select()
        .order('descricao');

    return response.map<Produto>((item) => Produto.fromMap(item)).toList();
  }

  Future<void> inserir({
    required String codigo,
    required String descricao,
    required double precoCusto,
    required double precoVenda,
    required double estoqueInicial,
  }) async {
    final response = await supabase
        .from('produtos')
        .insert({
          'codigo': codigo,
          'descricao': descricao,
          'preco_custo': precoCusto,
          'preco_venda': precoVenda,
          'estoque_atual': estoqueInicial,
        })
        .select()
        .single();

    final produtoId = response['id'];

    if (estoqueInicial > 0) {
      await supabase.from('movimentacoes_estoque').insert({
        'produto_id': produtoId,
        'tipo': 'entrada',
        'quantidade': estoqueInicial,
        'observacao': 'Estoque inicial',
      });
    }
  }

  Future<String> gerarProximoCodigo() async {
    final response = await supabase
        .from('produtos')
        .select('codigo')
        .order('codigo', ascending: false)
        .limit(1);

    if (response.isEmpty) return '001';

    final ultimo = int.tryParse(response.first['codigo'].toString()) ?? 0;

    final proximo = ultimo + 1;

    return proximo.toString().padLeft(3, '0');
  }

  Future<void> atualizar({
    required String id,
    required String descricao,
    required double precoCusto,
    required double precoVenda,
  }) async {
    await supabase
        .from('produtos')
        .update({
          'descricao': descricao,
          'preco_custo': precoCusto,
          'preco_venda': precoVenda,
        })
        .eq('id', id);
  }
}
