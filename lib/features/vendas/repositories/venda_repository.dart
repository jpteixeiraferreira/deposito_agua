import 'package:supabase_flutter/supabase_flutter.dart';

class VendaRepository {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> buscarClientes() async {
    final response = await supabase
        .from('clientes')
        .select('id, nome')
        .order('nome', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> buscarProdutos() async {
    final response = await supabase
        .from('produtos')
        .select('id, descricao, preco_venda, estoque_atual')
        .order('descricao', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> criarVenda({
    required String clienteId,
    required double total,
  }) async {
    final response = await supabase
        .from('vendas')
        .insert({'cliente_id': clienteId, 'total': total})
        .select()
        .single();

    return response['id'];
  }

  Future<void> inserirItem({
    required String vendaId,
    required String produtoId,
    required double quantidade,
    required double preco,
  }) async {
    await supabase.from('venda_itens').insert({
      'venda_id': vendaId,
      'produto_id': produtoId,
      'quantidade': quantidade,
      'preco_unitario': preco,
      'subtotal': quantidade * preco,
    });
  }

  Future<void> baixarEstoque({
    required String produtoId,
    required double quantidade,
    required double estoqueAtual,
  }) async {
    final novo = estoqueAtual - quantidade;

    await supabase
        .from('produtos')
        .update({'estoque_atual': novo})
        .eq('id', produtoId);

    await supabase.from('movimentacoes_estoque').insert({
      'produto_id': produtoId,
      'tipo': 'venda',
      'quantidade': quantidade,
    });
  }
}
