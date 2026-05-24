import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/empresa_context.dart';

class RelatorioRepository {
  final supabase = Supabase.instance.client;

  ({DateTime inicio, DateTime fim}) intervaloHoje() {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month, agora.day);
    final fim = inicio.add(const Duration(days: 1));

    return (inicio: inicio, fim: fim);
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _filtroPeriodo(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query, {
    DateTime? inicio,
    DateTime? fim,
    String coluna = 'data_venda',
  }) {
    var filtrada = query;
    if (inicio != null) filtrada = filtrada.gte(coluna, inicio.toIso8601String());
    if (fim != null) filtrada = filtrada.lt(coluna, fim.toIso8601String());
    return filtrada;
  }

  Future<List<Map<String, dynamic>>> buscarVendas({
    DateTime? inicio,
    DateTime? fim,
    String? clienteId,
    String? produtoId,
    bool incluirCanceladas = true,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final select = produtoId == null
        ? '''
          id,
          numero,
          status,
          total,
          data_venda,
          clientes:cliente_id (
            nome
          ),
          venda_itens (
            quantidade,
            preco_unitario,
            subtotal,
            produtos:produto_id (
              id,
              codigo,
              descricao,
              preco_custo
            )
          )
        '''
        : '''
          id,
          numero,
          status,
          total,
          data_venda,
          clientes:cliente_id (
            nome
          ),
          venda_itens!inner (
            quantidade,
            preco_unitario,
            subtotal,
            produtos:produto_id (
              id,
              codigo,
              descricao,
              preco_custo
            )
          )
        ''';

    var query = supabase.from('vendas').select(select);
    query = query.eq('empresa_id', empresaId);
    query = _filtroPeriodo(query, inicio: inicio, fim: fim);

    if (clienteId != null) query = query.eq('cliente_id', clienteId);
    if (produtoId != null) query = query.eq('venda_itens.produto_id', produtoId);
    if (!incluirCanceladas) query = query.neq('status', 'cancelada');

    final response = await query.order('data_venda', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> buscarPagamentos({
    DateTime? inicio,
    DateTime? fim,
    String? clienteId,
    String? produtoId,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final response = await buscarVendas(
      inicio: inicio,
      fim: fim,
      clienteId: clienteId,
      produtoId: produtoId,
      incluirCanceladas: false,
    );

    final pagamentos = <Map<String, dynamic>>[];
    for (final venda in response) {
      final vendaCompleta = await supabase
          .from('pagamentos')
          .select('tipo, valor')
          .eq('empresa_id', empresaId)
          .eq('venda_id', venda['id']);
      pagamentos.addAll(List<Map<String, dynamic>>.from(vendaCompleta));
    }

    return pagamentos;
  }

  Future<List<Map<String, dynamic>>> buscarProdutosVendidos({
    DateTime? inicio,
    DateTime? fim,
    String? clienteId,
    String? produtoId,
  }) async {
    final vendas = await buscarVendas(
      inicio: inicio,
      fim: fim,
      clienteId: clienteId,
      produtoId: produtoId,
      incluirCanceladas: false,
    );

    final itens = <Map<String, dynamic>>[];
    for (final venda in vendas) {
      itens.addAll(List<Map<String, dynamic>>.from(venda['venda_itens'] ?? []));
    }

    return itens;
  }

  Future<List<Map<String, dynamic>>> buscarMovimentacoesEstoque({
    DateTime? inicio,
    DateTime? fim,
    String? produtoId,
  }) async {
    Future<List<Map<String, dynamic>>> buscarComSelect(String select) async {
      final empresaId = await EmpresaContext.instance.empresaId();
      var query = supabase.from('movimentacoes_estoque').select(select);

      query = query.eq('empresa_id', empresaId);
      query = _filtroPeriodo(
        query,
        inicio: inicio,
        fim: fim,
        coluna: 'criado_em',
      );
      if (produtoId != null) query = query.eq('produto_id', produtoId);

      final response = await query.order('criado_em', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    }

    const selectComAuditoria = '''
      id,
      tipo,
      motivo,
      quantidade,
      custo_unitario,
      observacao,
      criado_em,
      produtos:produto_id (
        id,
        codigo,
        descricao,
        preco_custo,
        preco_venda
      )
    ''';

    const selectLegado = '''
      id,
      tipo,
      quantidade,
      observacao,
      criado_em,
      produtos:produto_id (
        id,
        codigo,
        descricao,
        preco_custo,
        preco_venda
      )
    ''';

    try {
      return buscarComSelect(selectComAuditoria);
    } on PostgrestException {
      return buscarComSelect(selectLegado);
    }
  }

  Future<List<Map<String, dynamic>>> buscarVendasDoDia() async {
    final intervalo = intervaloHoje();
    return buscarVendas(inicio: intervalo.inicio, fim: intervalo.fim);
  }

  Future<List<Map<String, dynamic>>> buscarPagamentosDoDia() async {
    final intervalo = intervaloHoje();
    return buscarPagamentos(inicio: intervalo.inicio, fim: intervalo.fim);
  }

  Future<List<Map<String, dynamic>>> buscarProdutosVendidosDoDia() async {
    final intervalo = intervaloHoje();
    return buscarProdutosVendidos(inicio: intervalo.inicio, fim: intervalo.fim);
  }
}
