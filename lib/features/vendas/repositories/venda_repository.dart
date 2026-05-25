import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/empresa_context.dart';

class VendaRepository {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> buscarClientes() async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await supabase
        .from('clientes')
        .select('id, nome')
        .eq('empresa_id', empresaId)
        .eq('ativo', true)
        .order('nome', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> buscarProdutos() async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await supabase
        .from('produtos')
        .select('id, descricao, preco_venda, estoque_atual')
        .eq('empresa_id', empresaId)
        .eq('ativo', true)
        .order('descricao', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<int> gerarProximoNumero() async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await supabase
        .from('vendas')
        .select('numero')
        .eq('empresa_id', empresaId)
        .not('numero', 'is', null)
        .order('numero', ascending: false)
        .limit(1);

    if (response.isEmpty) return 1;

    final ultimo = int.tryParse(response.first['numero'].toString()) ?? 0;
    return ultimo + 1;
  }

  Future<String> criarVenda({
    required String clienteId,
    required double subtotal,
    required String descontoTipo,
    required double descontoValor,
    required double descontoTotal,
    required double total,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await supabase
        .from('vendas')
        .insert({
          'empresa_id': empresaId,
          'cliente_id': clienteId,
          'numero': await gerarProximoNumero(),
          'subtotal': subtotal,
          'desconto_tipo': descontoTipo,
          'desconto_valor': descontoValor,
          'desconto_total': descontoTotal,
          'total': total,
          'data_venda': DateTime.now().toIso8601String(),
          'status': 'finalizada',
        })
        .select()
        .single();

    return response['id'].toString();
  }

  Future<Map<String, dynamic>> buscarVendaDetalhada(String vendaId) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await supabase
        .from('vendas')
        .select('''
          id,
          numero,
          status,
          subtotal,
          desconto_tipo,
          desconto_valor,
          desconto_total,
          total,
          data_venda,
          cancelada_em,
          motivo_cancelamento,
          clientes:cliente_id (
            nome,
            telefone,
            endereco,
            referencia,
            cpf_cnpj
          ),
          venda_itens (
            produto_id,
            quantidade,
            preco_unitario,
            desconto_tipo,
            desconto_valor,
            desconto_total,
            subtotal,
            produtos:produto_id (
              id,
              codigo,
              descricao,
              preco_custo,
              estoque_atual
            )
          ),
          pagamentos (
            tipo,
            valor
          )
        ''')
        .eq('empresa_id', empresaId)
        .eq('id', vendaId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> buscarVendaPorNumero(int numero) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await supabase
        .from('vendas')
        .select('''
          id,
          numero,
          status,
          subtotal,
          desconto_tipo,
          desconto_valor,
          desconto_total,
          total,
          data_venda,
          clientes:cliente_id (
            nome
          )
        ''')
        .eq('empresa_id', empresaId)
        .eq('numero', numero)
        .maybeSingle();

    if (response == null) return null;
    return Map<String, dynamic>.from(response);
  }

  Future<void> inserirItem({
    required String vendaId,
    required String produtoId,
    required double quantidade,
    required double preco,
    required String descontoTipo,
    required double descontoValor,
    required double descontoTotal,
    required double subtotal,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    await supabase.from('venda_itens').insert({
      'empresa_id': empresaId,
      'venda_id': vendaId,
      'produto_id': produtoId,
      'quantidade': quantidade,
      'preco_unitario': preco,
      'desconto_tipo': descontoTipo,
      'desconto_valor': descontoValor,
      'desconto_total': descontoTotal,
      'subtotal': subtotal,
    });
  }

  Future<void> baixarEstoque({
    required String produtoId,
    required double quantidade,
    required double estoqueAtual,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final novo = estoqueAtual - quantidade;

    await supabase
        .from('produtos')
        .update({'estoque_atual': novo})
        .eq('empresa_id', empresaId)
        .eq('id', produtoId);

    await supabase.from('movimentacoes_estoque').insert({
      'empresa_id': empresaId,
      'produto_id': produtoId,
      'tipo': 'venda',
      'quantidade': quantidade,
    });
  }

  Future<void> inserirPagamento({
    required String vendaId,
    required String tipo,
    required double valor,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    await supabase.from('pagamentos').insert({
      'empresa_id': empresaId,
      'venda_id': vendaId,
      'tipo': tipo,
      'valor': valor,
    });
  }

  Future<void> cancelarVenda({
    required String vendaId,
    required String motivo,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final venda = await buscarVendaDetalhada(vendaId);
    final status = (venda['status'] ?? 'finalizada').toString();

    if (status == 'cancelada') return;

    final itens = List<Map<String, dynamic>>.from(venda['venda_itens'] ?? []);

    for (final item in itens) {
      final produto = item['produtos'] as Map<String, dynamic>? ?? {};
      final produtoId = (item['produto_id'] ?? produto['id']).toString();
      final quantidade = ((item['quantidade'] as num?)?.toDouble() ?? 0);
      final estoqueAtual =
          ((produto['estoque_atual'] as num?)?.toDouble() ?? 0);

      if (produtoId.isEmpty || quantidade <= 0) continue;

      await supabase
          .from('produtos')
          .update({'estoque_atual': estoqueAtual + quantidade})
          .eq('empresa_id', empresaId)
          .eq('id', produtoId);

      await supabase.from('movimentacoes_estoque').insert({
        'empresa_id': empresaId,
        'produto_id': produtoId,
        'tipo': 'cancelamento_venda',
        'quantidade': quantidade,
        'observacao': motivo.trim().isEmpty
            ? 'Estorno por cancelamento de venda'
            : motivo.trim(),
      });
    }

    await supabase
        .from('vendas')
        .update({
          'status': 'cancelada',
          'cancelada_em': DateTime.now().toIso8601String(),
          'motivo_cancelamento': motivo.trim(),
        })
        .eq('empresa_id', empresaId)
        .eq('id', vendaId);
  }
}
