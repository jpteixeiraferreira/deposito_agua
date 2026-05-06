import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/app_top_bar.dart';
import '../../vendas/repositories/venda_repository.dart';
import '../models/config_recibo_model.dart';
import '../pdf/recibo_venda_pdf.dart';
import '../pdf/relatorio_vendas_pdf.dart';
import '../repositories/config_recibo_repository.dart';
import '../repositories/relatorio_repository.dart';

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  final repo = RelatorioRepository();
  final configRepo = ConfigReciboRepository();
  final vendaRepo = VendaRepository();

  bool loading = true;

  List<Map<String, dynamic>> vendas = [];
  List<Map<String, dynamic>> pagamentos = [];
  List<Map<String, dynamic>> produtosVendidos = [];
  late DateTime inicio;
  late DateTime fim;
  ConfigRecibo configRecibo = ConfigRecibo.padrao();
  bool relatorioDetalhado = false;

  @override
  void initState() {
    super.initState();
    final intervalo = repo.intervaloHoje();
    inicio = intervalo.inicio;
    fim = intervalo.fim;
    carregar();
  }

  Future<void> carregar() async {
    setState(() => loading = true);

    final configData = await configRepo.buscar();
    final vendasData = await repo.buscarVendas(inicio: inicio, fim: fim);
    final pagamentosData = await repo.buscarPagamentos(inicio: inicio, fim: fim);
    final produtosData = await repo.buscarProdutosVendidos(
      inicio: inicio,
      fim: fim,
    );

    if (!mounted) return;

    setState(() {
      vendas = vendasData;
      pagamentos = pagamentosData;
      produtosVendidos = produtosData;
      configRecibo = configData;
      loading = false;
    });
  }

  Future<void> selecionarPeriodo() async {
    final periodo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: inicio,
        end: fim.subtract(const Duration(days: 1)),
      ),
    );

    if (periodo == null) return;

    setState(() {
      inicio = DateTime(periodo.start.year, periodo.start.month, periodo.start.day);
      fim = DateTime(
        periodo.end.year,
        periodo.end.month,
        periodo.end.day,
      ).add(const Duration(days: 1));
    });

    await carregar();
  }

  Future<void> voltarParaHoje() async {
    final intervalo = repo.intervaloHoje();
    setState(() {
      inicio = intervalo.inicio;
      fim = intervalo.fim;
    });

    await carregar();
  }

  Future<void> exportarPdf() async {
    await Printing.layoutPdf(
      name: 'relatorio-vendas-${dataArquivo(inicio)}-${dataArquivo(fimExibicao)}.pdf',
      onLayout: (_) => RelatorioVendasPdf.gerar(
        inicio: inicio,
        fim: fimExibicao,
        vendas: vendas,
        totaisPorPagamento: totaisPorPagamento,
        resumoProdutos: resumoProdutos,
        detalhado: relatorioDetalhado,
      ),
    );
  }

  Future<void> imprimirRecibo(String vendaId) async {
    final venda = await vendaRepo.buscarVendaDetalhada(vendaId);

    await Printing.layoutPdf(
      name: 'recibo-venda-$vendaId.pdf',
      onLayout: (_) => ReciboVendaPdf.gerar(venda, config: configRecibo),
    );
  }

  Future<void> configurarRecibo() async {
    final resultado = await showDialog<ConfigRecibo>(
      context: context,
      builder: (_) => ConfigReciboDialog(config: configRecibo),
    );

    if (resultado == null) return;

    try {
      await configRepo.salvar(resultado);

      if (!mounted) return;

      setState(() {
        configRecibo = resultado;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuração do recibo salva')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar a configuração do recibo'),
        ),
      );
    }
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

  DateTime get fimExibicao {
    return fim.subtract(const Duration(days: 1));
  }

  String dataTexto(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  String dataArquivo(DateTime data) {
    return '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
  }

  String get periodoTexto {
    if (dataTexto(inicio) == dataTexto(fimExibicao)) {
      return dataTexto(inicio);
    }

    return '${dataTexto(inicio)} até ${dataTexto(fimExibicao)}';
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

            if (totais.isEmpty)
              const Text('Nenhum pagamento registrado no período'),

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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Nenhuma venda no período')),
      );
    }

    return Column(
      children: vendas.map((venda) {
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  moeda(total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Imprimir recibo',
                  icon: const Icon(Icons.print),
                  onPressed: () => imprimirRecibo(venda['id'].toString()),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
              'Produtos vendidos no período',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (resumo.isEmpty) const Text('Nenhum produto vendido no período'),

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Período do relatório: $periodoTexto',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: selecionarPeriodo,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Escolher período'),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Resumo')),
                    ButtonSegment(value: true, label: Text('Detalhado')),
                  ],
                  selected: {relatorioDetalhado},
                  onSelectionChanged: (value) {
                    setState(() {
                      relatorioDetalhado = value.first;
                    });
                  },
                ),
                OutlinedButton.icon(
                  onPressed: configurarRecibo,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configurar recibo'),
                ),
                OutlinedButton.icon(
                  onPressed: voltarParaHoje,
                  icon: const Icon(Icons.today),
                  label: const Text('Hoje'),
                ),
                ElevatedButton.icon(
                  onPressed: exportarPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Exportar PDF'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 280,
                  child: cardResumo(
                    titulo: 'Total vendido',
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
                'Vendas do período',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 8),

            listaVendas(),
          ],
        ),
      ),
    );
  }
}

class ConfigReciboDialog extends StatefulWidget {
  final ConfigRecibo config;

  const ConfigReciboDialog({super.key, required this.config});

  @override
  State<ConfigReciboDialog> createState() => _ConfigReciboDialogState();
}

class _ConfigReciboDialogState extends State<ConfigReciboDialog> {
  final repo = ConfigReciboRepository();
  final nomeEmpresa = TextEditingController();
  final endereco = TextEditingController();
  final cidade = TextEditingController();
  final email = TextEditingController();
  final telefone = TextEditingController();
  final logoUrl = TextEditingController();
  final rodape = TextEditingController();
  double logoTamanho = 100;
  bool enviandoLogo = false;

  @override
  void initState() {
    super.initState();
    nomeEmpresa.text = widget.config.nomeEmpresa;
    endereco.text = widget.config.endereco;
    cidade.text = widget.config.cidade;
    email.text = widget.config.email;
    telefone.text = widget.config.telefone;
    logoUrl.text = widget.config.logoUrl;
    logoTamanho = widget.config.logoTamanho;
    rodape.text = widget.config.rodape;
  }

  @override
  void dispose() {
    nomeEmpresa.dispose();
    endereco.dispose();
    cidade.dispose();
    email.dispose();
    telefone.dispose();
    logoUrl.dispose();
    rodape.dispose();
    super.dispose();
  }

  InputDecoration deco(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  Widget campo(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: controller, decoration: deco(label)),
    );
  }

  ConfigRecibo configAtual() {
    return ConfigRecibo(
      nomeEmpresa: nomeEmpresa.text.trim(),
      endereco: endereco.text.trim(),
      cidade: cidade.text.trim(),
      email: email.text.trim(),
      telefone: telefone.text.trim(),
      logoUrl: logoUrl.text.trim(),
      logoTamanho: logoTamanho,
      rodape: rodape.text.trim(),
    );
  }

  Future<void> escolherLogo() async {
    final arquivo = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (arquivo == null || arquivo.files.single.bytes == null) return;

    try {
      setState(() => enviandoLogo = true);

      final url = await repo.enviarLogo(
        bytes: arquivo.files.single.bytes!,
        nomeArquivo: arquivo.files.single.name,
      );

      logoUrl.text = url;
      setState(() {});
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível enviar a logo')),
      );
    } finally {
      if (mounted) {
        setState(() => enviandoLogo = false);
      }
    }
  }

  Future<void> visualizarRecibo() async {
    await Printing.layoutPdf(
      name: 'preview-recibo.pdf',
      onLayout: (_) => ReciboVendaPdf.gerar(
        {
          'id': '000001',
          'total': 40.0,
          'data_venda': DateTime.now().toIso8601String(),
          'clientes': {
            'nome': 'Cliente de exemplo',
            'endereco': 'Rua de exemplo, nº 123',
            'cpf_cnpj': '000.000.000-00',
          },
          'venda_itens': [
            {
              'quantidade': 2,
              'preco_unitario': 20.0,
              'subtotal': 40.0,
              'produtos': {
                'codigo': '001',
                'descricao': 'Produto de exemplo',
              },
            },
          ],
          'pagamentos': [
            {'tipo': 'pix', 'valor': 40.0},
          ],
        },
        config: configAtual(),
      ),
    );
  }

  void salvar() {
    Navigator.pop(context, configAtual());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar recibo'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              campo('Nome da empresa', nomeEmpresa),
              campo('Endereço', endereco),
              campo('Cidade/UF', cidade),
              campo('E-mail', email),
              campo('Telefone', telefone),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: logoUrl,
                        decoration: deco('URL da logo'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: enviandoLogo ? null : escolherLogo,
                      icon: enviandoLogo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: const Text('Enviar logo'),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tamanho da logo: ${logoTamanho.toStringAsFixed(0)}',
                ),
              ),
              if (logoUrl.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Image.network(
                      logoUrl.text.trim(),
                      height: 90,
                      errorBuilder: (_, __, ___) {
                        return const Text('Não foi possível carregar a logo');
                      },
                    ),
                  ),
                ),
              Slider(
                value: logoTamanho,
                min: 60,
                max: 160,
                divisions: 10,
                onChanged: (value) {
                  setState(() {
                    logoTamanho = value;
                  });
                },
              ),
              campo('Rodapé/assinatura', rodape),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: visualizarRecibo,
          icon: const Icon(Icons.visibility),
          label: const Text('Pré-visualizar'),
        ),
        ElevatedButton(onPressed: salvar, child: const Text('Salvar')),
      ],
    );
  }
}
