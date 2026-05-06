import 'package:supabase_flutter/supabase_flutter.dart';

class RelatorioRepository {
  final supabase = Supabase.instance.client;

  ({DateTime inicio, DateTime fim}) intervaloHoje() {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month, agora.day);
    final fim = inicio.add(const Duration(days: 1));

    return (inicio: inicio, fim: fim);
  }

  Future<List<Map<String, dynamic>>> buscarVendas({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final response = await supabase
        .from('vendas')
        .select('''
          id,
          total,
          data_venda,
          cliente_id,
          clientes:cliente_id (
            nome
          )
        ''')
        .gte('data_venda', inicio.toIso8601String())
        .lt('data_venda', fim.toIso8601String())
        .order('data_venda', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> buscarPagamentos({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final response = await supabase
        .from('pagamentos')
        .select('''
          tipo,
          valor,
          vendas!inner (
            data_venda
          )
        ''')
        .gte('vendas.data_venda', inicio.toIso8601String())
        .lt('vendas.data_venda', fim.toIso8601String());

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> buscarProdutosVendidos({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final response = await supabase
        .from('venda_itens')
        .select('''
        quantidade,
        subtotal,
        produtos (
          descricao
        ),
        vendas!inner (
          data_venda
        )
      ''')
        .gte('vendas.data_venda', inicio.toIso8601String())
        .lt('vendas.data_venda', fim.toIso8601String());

    return List<Map<String, dynamic>>.from(response);
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
