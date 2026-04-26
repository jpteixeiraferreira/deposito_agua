import 'package:flutter/material.dart';

import '../../../core/widgets/app_top_bar.dart';
import '../repositories/relatorio_repository.dart';

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  final repo = RelatorioRepository();

  bool loading = true;

  List<Map<String, dynamic>> vendas = [];
  List<Map<String, dynamic>> pagamentos = [];
  List<Map<String, dynamic>> produtosVendidos = [];

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    final vendasData = await repo.buscarVendasDoDia();
    final pagamentosData = await repo.buscarPagamentosDoDia();
    final produtosData = await repo.buscarProdutosVendidosDoDia();

    if (!mounted) return;

    setState(() {
      vendas = vendasData;
      pagamentos = pagamentosData;
      produtosVendidos = produtosData;
      loading = false;
    });
  }

  Map<String, Map<String, double>> get resumoProdutos {
    final mapa = <String, Map<String, double>>{};

    for (final item in produtosVendidos) {
      final produto = item['produtos'];
      final nome = produto != null
          ? produto['descricao'].toString()
          : 'Produto';

      final qtd = ((item['quantidade'] as num?)?.toDouble() ?? 0);
      final subtotal = ((item['subtotal'] as num?)?.toDouble() ?? 0);

      mapa[nome] ??= {'quantidade': 0, 'total': 0};

      mapa[nome]!['quantidade'] = mapa[nome]!['quantidade']! + qtd;
      mapa[nome]!['total'] = mapa[nome]!['total']! + subtotal;
    }

    return mapa;
  }

  String moeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  double get totalVendido {
    return vendas.fold(
      0,
      (soma, venda) => soma + ((venda['total'] as num?)?.toDouble() ?? 0),
    );
  }

  Map<String, double> get totaisPorPagamento {
    final mapa = <String, double>{};

    for (final pagamento in pagamentos) {
      final tipo = pagamento['tipo'].toString();
      final valor = ((pagamento['valor'] as num?)?.toDouble() ?? 0);

      mapa[tipo] = (mapa[tipo] ?? 0) + valor;
    }

    return mapa;
  }

  String nomeFormaPagamento(String tipo) {
    switch (tipo) {
      case 'dinheiro':
        return 'Dinheiro';
      case 'pix':
        return 'Pix';
      case 'debito':
        return 'Débito';
      case 'credito':
        return 'Crédito';
      default:
        return tipo;
    }
  }

  Widget cardResumo({
    required String titulo,
    required String valor,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 34),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget resumoPagamentos() {
    final totais = totaisPorPagamento;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Formas de pagamento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (totais.isEmpty) const Text('Nenhum pagamento registrado hoje'),

            ...totais.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(nomeFormaPagamento(entry.key)),
                    Text(
                      moeda(entry.value),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget listaVendas() {
    if (vendas.isEmpty) {
      return const Center(child: Text('Nenhuma venda realizada hoje'));
    }

    return ListView.builder(
      itemCount: vendas.length,
      itemBuilder: (context, index) {
        final venda = vendas[index];

        final cliente = venda['clientes'];
        final nomeCliente = cliente != null
            ? cliente['nome'].toString()
            : 'Sem cliente';

        final total = ((venda['total'] as num?)?.toDouble() ?? 0);

        final data = DateTime.tryParse(venda['data_venda'].toString());

        final hora = data == null
            ? ''
            : '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';

        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(nomeCliente),
            subtitle: Text('Horário: $hora'),
            trailing: Text(
              moeda(total),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget produtosVendidosCard() {
    final resumo = resumoProdutos.entries.toList()
      ..sort(
        (a, b) => b.value['quantidade']!.compareTo(a.value['quantidade']!),
      );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produtos vendidos hoje',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (resumo.isEmpty) const Text('Nenhum produto vendido hoje'),

            ...resumo.map((entry) {
              final nome = entry.key;
              final qtd = entry.value['quantidade'] ?? 0;
              final total = entry.value['total'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(nome)),
                    Text(
                      '${qtd.toStringAsFixed(0)} un. • ${moeda(total)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        appBar: AppTopBar(titulo: 'Relatórios'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const AppTopBar(titulo: 'Relatórios'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 280,
                  child: cardResumo(
                    titulo: 'Total vendido hoje',
                    valor: moeda(totalVendido),
                    icon: Icons.attach_money,
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: cardResumo(
                    titulo: 'Quantidade de vendas',
                    valor: vendas.length.toString(),
                    icon: Icons.point_of_sale,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            resumoPagamentos(),

            const SizedBox(height: 16),

            produtosVendidosCard(),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Vendas do dia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 8),

            Expanded(child: listaVendas()),
          ],
        ),
      ),
    );
  }
}
