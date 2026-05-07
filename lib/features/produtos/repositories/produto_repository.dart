import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/empresa_context.dart';
import '../models/produto_model.dart';

class ProdutoRepository {
  final supabase = Supabase.instance.client;

  Future<List<Produto>> buscarTodos({
    bool incluirInativos = false,
    bool somenteInativos = false,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    var query = supabase.from('produtos').select();
    query = query.eq('empresa_id', empresaId);

    if (somenteInativos) {
      query = query.eq('ativo', false);
    } else if (!incluirInativos) {
      query = query.eq('ativo', true);
    }

    final response = await query.order('descricao');

    return response.map<Produto>((item) => Produto.fromMap(item)).toList();
  }

  Future<void> inserir({
    required String codigo,
    required String descricao,
    required double precoCusto,
    required double precoVenda,
    required double estoqueInicial,
  }) async {
    _validarPrecos(precoCusto: precoCusto, precoVenda: precoVenda);
    final empresaId = await EmpresaContext.instance.empresaId();

    final response = await supabase
        .from('produtos')
        .insert({
          'empresa_id': empresaId,
          'codigo': codigo,
          'descricao': descricao,
          'preco_custo': precoCusto,
          'preco_venda': precoVenda,
          'estoque_atual': estoqueInicial,
          'ativo': true,
        })
        .select()
        .single();

    final produtoId = response['id'];

    if (estoqueInicial > 0) {
      await supabase.from('movimentacoes_estoque').insert({
        'empresa_id': empresaId,
        'produto_id': produtoId,
        'tipo': 'entrada',
        'quantidade': estoqueInicial,
        'observacao': 'Estoque inicial',
      });
    }
  }

  Future<String> gerarProximoCodigo() async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await supabase
        .from('produtos')
        .select('codigo')
        .eq('empresa_id', empresaId)
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
    required bool ativo,
  }) async {
    _validarPrecos(precoCusto: precoCusto, precoVenda: precoVenda);
    final empresaId = await EmpresaContext.instance.empresaId();

    await supabase
        .from('produtos')
        .update({
          'descricao': descricao,
          'preco_custo': precoCusto,
          'preco_venda': precoVenda,
          'ativo': ativo,
        })
        .eq('empresa_id', empresaId)
        .eq('id', id);
  }

  Future<bool> excluir(String id) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    try {
      await supabase
          .from('produtos')
          .delete()
          .eq('empresa_id', empresaId)
          .eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23503') return false;
      rethrow;
    }
  }

  Future<void> inativar(String id) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    await supabase
        .from('produtos')
        .update({'ativo': false})
        .eq('empresa_id', empresaId)
        .eq('id', id);
  }

  Future<void> movimentarEstoque({
    required Produto produto,
    required String tipo,
    required double quantidade,
    required String observacao,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final delta = tipo == 'entrada' ? quantidade : -quantidade;
    final novoEstoque = produto.estoqueAtual + delta;

    if (novoEstoque < 0) {
      throw Exception('Estoque insuficiente para saida');
    }

    await supabase
        .from('produtos')
        .update({'estoque_atual': novoEstoque})
        .eq('empresa_id', empresaId)
        .eq('id', produto.id);

    await supabase.from('movimentacoes_estoque').insert({
      'empresa_id': empresaId,
      'produto_id': produto.id,
      'tipo': tipo,
      'quantidade': quantidade,
      'observacao': observacao.trim().isEmpty
          ? 'Movimentacao manual'
          : observacao.trim(),
    });
  }

  void _validarPrecos({
    required double precoCusto,
    required double precoVenda,
  }) {
    if (precoVenda <= 0) {
      throw ArgumentError('Preco de venda invalido');
    }

    if (precoCusto > precoVenda) {
      throw ArgumentError('Custo maior que preco de venda');
    }
  }
}
