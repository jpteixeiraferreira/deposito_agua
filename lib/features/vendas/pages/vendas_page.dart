import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/app_top_bar.dart';
import '../../relatorios/pdf/recibo_venda_pdf.dart';
import '../../relatorios/repositories/config_recibo_repository.dart';
import '../../clientes/models/cliente_model.dart';
import '../../clientes/repositories/cliente_repository.dart';
import '../../produtos/models/produto_model.dart';
import '../../produtos/repositories/produto_repository.dart';
import '../repositories/venda_repository.dart';

class VendasPage extends StatefulWidget {
  const VendasPage({super.key});

  @override
  State<VendasPage> createState() => _VendasPageState();
}

class _VendasPageState extends State<VendasPage> {
  final vendaRepo = VendaRepository();
  final configReciboRepo = ConfigReciboRepository();
  final clienteRepo = ClienteRepository();
  final produtoRepo = ProdutoRepository();

  final clienteBuscaController = TextEditingController();
  final produtoBuscaController = TextEditingController();
  final qtdController = TextEditingController(text: '1');

  final clienteFocus = FocusNode();
  final produtoFocus = FocusNode();
  final qtdFocus = FocusNode();

  final produtoScrollController = ScrollController();

  final valorPagamentoController = TextEditingController();

  String tipoPagamento = 'dinheiro';

  final List<Map<String, dynamic>> pagamentos = [];

  List<Cliente> clientes = [];
  List<Produto> produtos = [];

  Cliente? clienteSelecionado;
  Produto? produtoSelecionado;

  final List<Map<String, dynamic>> itens = [];

  bool loading = true;
  bool salvando = false;

  bool mostrarSugestoesCliente = false;
  bool mostrarTodosProdutos = false;

  int clienteIndexSelecionado = 0;
  int produtoIndexSelecionado = 0;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  @override
  void dispose() {
    clienteBuscaController.dispose();
    produtoBuscaController.dispose();
    qtdController.dispose();

    clienteFocus.dispose();
    produtoFocus.dispose();
    qtdFocus.dispose();

    produtoScrollController.dispose();
    valorPagamentoController.dispose();
    super.dispose();
  }

  Future<void> carregarDados() async {
    final clientesData = await clienteRepo.buscarTodos();
    final produtosData = await produtoRepo.buscarTodos();

    if (!mounted) return;

    setState(() {
      clientes = clientesData;
      produtos = produtosData;
      loading = false;
    });
  }

  String normalizar(String texto) {
    const com = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    const sem = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

    for (int i = 0; i < com.length; i++) {
      texto = texto.replaceAll(com[i], sem[i]);
    }

    return texto.toLowerCase();
  }

  String apenasNumeros(String texto) {
    return texto.replaceAll(RegExp(r'[^0-9]'), '');
  }

  int paraCentavos(double valor) {
    return (valor * 100).round();
  }

  double deCentavos(int centavos) {
    return centavos / 100;
  }

  double parseMoeda(String valor) {
    final limpo = valor.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(limpo) ?? 0;
  }

  String moeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  double get total {
    return itens.fold(0, (soma, item) => soma + (item['subtotal'] as double));
  }

  List<Cliente> filtrarClientes(String busca) {
    final texto = normalizar(busca.trim());
    final numeros = apenasNumeros(busca);

    if (texto.isEmpty) return [];

    return clientes.where((c) {
      final dados = [
        c.nome,
        c.telefone,
        c.cpfCnpj,
        c.endereco,
        c.referencia,
      ].map(normalizar).join(' ');

      final numerosCliente = apenasNumeros('${c.telefone} ${c.cpfCnpj}');

      return dados.contains(texto) ||
          (numeros.isNotEmpty && numerosCliente.contains(numeros));
    }).toList();
  }

  List<Produto> filtrarProdutos(String busca) {
    final texto = normalizar(busca.trim());

    if (texto.isEmpty && !mostrarTodosProdutos) return [];

    if (texto.isEmpty && mostrarTodosProdutos) {
      return produtos;
    }

    return produtos.where((p) {
      final dados = normalizar('${p.codigo} ${p.descricao}');
      return dados.contains(texto);
    }).toList();
  }

  void rolarListaProdutos() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !produtoScrollController.hasClients) return;

      const itemHeight = 64.0;

      final destino = produtoIndexSelecionado * itemHeight;
      final max = produtoScrollController.position.maxScrollExtent;

      produtoScrollController.animateTo(
        destino.clamp(0, max),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  void selecionarCliente(Cliente cliente) {
    setState(() {
      clienteSelecionado = cliente;
      clienteBuscaController.text = cliente.nome;
      clienteIndexSelecionado = 0;
      mostrarSugestoesCliente = false;
    });

    produtoFocus.requestFocus();
  }

  void selecionarProduto(Produto produto) {
    setState(() {
      produtoSelecionado = produto;
      produtoBuscaController.text = '${produto.codigo} - ${produto.descricao}';
      produtoIndexSelecionado = 0;
      mostrarTodosProdutos = false;
    });

    qtdFocus.requestFocus();
  }

  void adicionarItem() {
    if (produtoSelecionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um produto')));
      produtoFocus.requestFocus();
      return;
    }

    final qtd = double.tryParse(qtdController.text.replaceAll(',', '.')) ?? 0;

    if (qtd <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quantidade inválida')));
      qtdFocus.requestFocus();
      return;
    }

    final p = produtoSelecionado!;

    if (p.precoVenda <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este produto esta sem preco de venda valido'),
        ),
      );
      produtoFocus.requestFocus();
      return;
    }

    final index = itens.indexWhere((i) => i['produto_id'] == p.id);

    final qtdAtual = index >= 0
        ? (itens[index]['quantidade'] as num).toDouble()
        : 0.0;

    final novaQtd = qtdAtual + qtd;

    if (novaQtd > p.estoqueAtual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estoque insuficiente. Disponível: ${p.estoqueAtual.toStringAsFixed(0)}',
          ),
        ),
      );
      return;
    }

    setState(() {
      if (index >= 0) {
        itens[index]['quantidade'] = novaQtd;
        itens[index]['subtotal'] = novaQtd * p.precoVenda;
      } else {
        itens.add({
          'produto_id': p.id,
          'descricao': p.descricao,
          'quantidade': qtd,
          'preco': p.precoVenda,
          'subtotal': qtd * p.precoVenda,
          'estoque': p.estoqueAtual,
        });
      }

      produtoSelecionado = null;
      produtoBuscaController.clear();
      qtdController.text = '1';
      produtoIndexSelecionado = 0;
      mostrarTodosProdutos = false;
    });

    produtoFocus.requestFocus();
  }

  int get totalCentavos {
    return paraCentavos(total);
  }

  int get totalPagoCentavos {
    return pagamentos.fold<int>(
      0,
      (soma, p) => soma + paraCentavos((p['valor'] as num).toDouble()),
    );
  }

  int get totalDinheiroCentavos {
    return pagamentos
        .where((p) => p['tipo'] == 'dinheiro')
        .fold<int>(
          0,
          (soma, p) => soma + paraCentavos((p['valor'] as num).toDouble()),
        );
  }

  int get totalSemDinheiroCentavos {
    return pagamentos
        .where((p) => p['tipo'] != 'dinheiro')
        .fold<int>(
          0,
          (soma, p) => soma + paraCentavos((p['valor'] as num).toDouble()),
        );
  }

  double get totalPago {
    return deCentavos(totalPagoCentavos);
  }

  double get faltaPagar {
    final falta = totalCentavos - totalPagoCentavos;
    return deCentavos(falta > 0 ? falta : 0);
  }

  double get troco {
    final restanteDepoisNaoDinheiro = totalCentavos - totalSemDinheiroCentavos;

    final trocoCentavos = totalDinheiroCentavos - restanteDepoisNaoDinheiro;

    return deCentavos(trocoCentavos > 0 ? trocoCentavos : 0);
  }

  void adicionarPagamento() {
    final valor = parseMoeda(valorPagamentoController.text);

    final valorCentavos = paraCentavos(valor);

    if (valorCentavos <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor de pagamento válido')),
      );
      return;
    }

    final novoTotalPagoCentavos = totalPagoCentavos + valorCentavos;

    if (tipoPagamento != 'dinheiro' && novoTotalPagoCentavos > totalCentavos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pix/cartão não pode ultrapassar o total da venda'),
        ),
      );
      return;
    }

    setState(() {
      pagamentos.add({
        'tipo': tipoPagamento,
        'valor': deCentavos(valorCentavos),
      });

      valorPagamentoController.clear();
    });
  }

  void sugerirPagamentoRestante() {
    final restante = faltaPagar;

    if (restante <= 0) return;

    valorPagamentoController.text = restante
        .toStringAsFixed(2)
        .replaceAll('.', ',');
  }

  Future<void> finalizarVenda() async {
    if (clienteSelecionado == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um cliente')));
      clienteFocus.requestFocus();
      return;
    }

    if (itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um produto')),
      );
      produtoFocus.requestFocus();
      return;
    }
    if (pagamentos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione pelo menos um pagamento')),
      );
      return;
    }

    if (totalPago < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ainda falta pagar ${moeda(faltaPagar)}')),
      );
      return;
    }
    try {
      setState(() => salvando = true);

      final vendaId = await vendaRepo.criarVenda(
        clienteId: clienteSelecionado!.id,
        total: total,
      );

      for (final item in itens) {
        await vendaRepo.inserirItem(
          vendaId: vendaId,
          produtoId: item['produto_id'],
          quantidade: (item['quantidade'] as num).toDouble(),
          preco: (item['preco'] as num).toDouble(),
        );

        await vendaRepo.baixarEstoque(
          produtoId: item['produto_id'],
          quantidade: (item['quantidade'] as num).toDouble(),
          estoqueAtual: (item['estoque'] as num).toDouble(),
        );
      }
      for (final pagamento in pagamentos) {
        await vendaRepo.inserirPagamento(
          vendaId: vendaId,
          tipo: pagamento['tipo'],
          valor: (pagamento['valor'] as num).toDouble(),
        );
      }

      final vendaDetalhada = await vendaRepo.buscarVendaDetalhada(vendaId);
      final configRecibo = await configReciboRepo.buscar();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venda realizada com sucesso')),
      );

      await Printing.layoutPdf(
        name: 'recibo-venda-$vendaId.pdf',
        onLayout: (_) => ReciboVendaPdf.gerar(
          vendaDetalhada,
          config: configRecibo,
        ),
      );

      if (!mounted) return;

      setState(() {
        clienteSelecionado = null;
        clienteBuscaController.clear();

        produtoSelecionado = null;
        produtoBuscaController.clear();

        qtdController.text = '1';
        pagamentos.clear();
        valorPagamentoController.clear();
        tipoPagamento = 'dinheiro';
        itens.clear();
      });

      await carregarDados();

      clienteFocus.requestFocus();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao finalizar venda')));
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  Widget campoCliente() {
    final resultados = filtrarClientes(clienteBuscaController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;

            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (resultados.isNotEmpty) {
                setState(() {
                  if (clienteIndexSelecionado < resultados.length - 1) {
                    clienteIndexSelecionado++;
                  }
                });
              }
              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (resultados.isNotEmpty) {
                setState(() {
                  if (clienteIndexSelecionado > 0) {
                    clienteIndexSelecionado--;
                  }
                });
              }
              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.enter) {
              if (resultados.isNotEmpty) {
                selecionarCliente(resultados[clienteIndexSelecionado]);
              }
              return KeyEventResult.handled;
            }

            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: clienteBuscaController,
            focusNode: clienteFocus,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Buscar cliente',
              hintText: 'Nome, telefone, CPF, endereço ou referência',
              border: const OutlineInputBorder(),
              suffixIcon: clienteSelecionado != null
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
            onChanged: (_) {
              setState(() {
                clienteSelecionado = null;
                clienteIndexSelecionado = 0;
                mostrarSugestoesCliente = true;
              });
            },
            onSubmitted: (_) {
              if (resultados.isNotEmpty) {
                selecionarCliente(resultados[clienteIndexSelecionado]);
              }
            },
          ),
        ),
        if (mostrarSugestoesCliente && resultados.isNotEmpty)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              height: 120,
              child: ListView.builder(
                itemExtent: 60,
                itemCount: resultados.length,
                itemBuilder: (context, index) {
                  final c = resultados[index];
                  final selecionado = index == clienteIndexSelecionado;

                  return ListTile(
                    selected: selecionado,
                    selectedTileColor: Colors.blue.shade50,
                    title: Text(c.nome),
                    subtitle: Text('${c.telefone} • ${c.endereco}'),
                    onTap: () => selecionarCliente(c),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget campoProduto() {
    final resultados = filtrarProdutos(produtoBuscaController.text);
    final alturaTela = MediaQuery.of(context).size.height;
    final alturaListaProdutos = (alturaTela * 0.35).clamp(180.0, 360.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;

            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              if (resultados.isNotEmpty) {
                setState(() {
                  if (produtoIndexSelecionado < resultados.length - 1) {
                    produtoIndexSelecionado++;
                  }
                });

                rolarListaProdutos();
              }

              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              if (resultados.isNotEmpty) {
                setState(() {
                  if (produtoIndexSelecionado > 0) {
                    produtoIndexSelecionado--;
                  }
                });

                rolarListaProdutos();
              }

              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.enter) {
              if (resultados.isNotEmpty) {
                selecionarProduto(resultados[produtoIndexSelecionado]);
              }

              return KeyEventResult.handled;
            }

            return KeyEventResult.ignored;
          },
          child: TextField(
            controller: produtoBuscaController,
            focusNode: produtoFocus,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Buscar produto',
              hintText: 'Código ou descrição',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Mostrar todos',
                icon: const Icon(Icons.list),
                onPressed: () {
                  setState(() {
                    mostrarTodosProdutos = !mostrarTodosProdutos;
                    produtoIndexSelecionado = 0;
                  });
                },
              ),
            ),
            onChanged: (_) {
              setState(() {
                produtoSelecionado = null;
                produtoIndexSelecionado = 0;
                mostrarTodosProdutos = false;
              });
            },
            onSubmitted: (_) {
              if (resultados.isNotEmpty) {
                selecionarProduto(resultados[produtoIndexSelecionado]);
              }
            },
          ),
        ),
        if (resultados.isNotEmpty)
          Material(
            color: Colors.white,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.hardEdge,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: alturaListaProdutos),
              child: ListView.builder(
                controller: produtoScrollController,
                itemExtent: 64,
                shrinkWrap: true,
                itemCount: resultados.length,
                itemBuilder: (context, index) {
                  final p = resultados[index];
                  final selecionado = index == produtoIndexSelecionado;

                  return ListTile(
                    selected: selecionado,
                    selectedTileColor: Colors.blue.shade50,
                    title: Text(
                      '${p.codigo} - ${p.descricao}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Estoque: ${p.estoqueAtual.toStringAsFixed(0)} • ${moeda(p.precoVenda)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => selecionarProduto(p),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget listaItens() {
    if (itens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('Nenhum item adicionado')),
      );
    }

    return Column(
      children: itens.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;

        final subtotal = moeda((item['subtotal'] as num).toDouble());
        final detalhe =
            '${item['quantidade']} x ${moeda((item['preco'] as num).toDouble())}';

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final remover = IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      itens.removeAt(i);
                    });
                  },
                );

                final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['descricao'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(detalhe),
                  ],
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      info,
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              subtotal,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          remover,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    Text(
                      subtotal,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    remover,
                  ],
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> consultarVenda() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => ConsultaVendaDialog(vendaRepo: vendaRepo),
    );

    if (resultado == true) {
      await carregarDados();
    }
  }

  Widget areaPagamentos() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pagamento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final telaEstreita = constraints.maxWidth < 560;

                final campoForma = SizedBox(
                  width: telaEstreita ? double.infinity : 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: tipoPagamento,
                    decoration: const InputDecoration(
                      labelText: 'Forma',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'dinheiro',
                        child: Text('Dinheiro'),
                      ),
                      DropdownMenuItem(value: 'pix', child: Text('Pix')),
                      DropdownMenuItem(value: 'debito', child: Text('Débito')),
                      DropdownMenuItem(
                        value: 'credito',
                        child: Text('Crédito'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;

                      setState(() {
                        tipoPagamento = v;
                      });
                    },
                  ),
                );

                final campoValor = TextField(
                  controller: valorPagamentoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => adicionarPagamento(),
                );

                final botaoRestante = SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: sugerirPagamentoRestante,
                    child: const Text('Restante'),
                  ),
                );

                final botaoAdicionar = SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: adicionarPagamento,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                  ),
                );

                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      campoForma,
                      const SizedBox(height: 10),
                      campoValor,
                      const SizedBox(height: 10),
                      botaoRestante,
                      const SizedBox(height: 10),
                      botaoAdicionar,
                    ],
                  );
                }

                if (telaEstreita) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      campoForma,
                      const SizedBox(height: 10),
                      campoValor,
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: botaoRestante),
                          const SizedBox(width: 10),
                          Expanded(child: botaoAdicionar),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    campoForma,
                    const SizedBox(width: 10),
                    Expanded(child: campoValor),
                    const SizedBox(width: 10),
                    botaoRestante,
                    const SizedBox(width: 10),
                    botaoAdicionar,
                  ],
                );
              },
            ),

            const SizedBox(height: 12),

            if (pagamentos.isEmpty) const Text('Nenhum pagamento adicionado'),

            if (pagamentos.isNotEmpty)
              Column(
                children: pagamentos.asMap().entries.map((entry) {
                  final index = entry.key;
                  final pagamento = entry.value;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tipo = pagamento['tipo'].toString().toUpperCase();
                        final valor = moeda(
                          (pagamento['valor'] as num).toDouble(),
                        );
                        final remover = IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              pagamentos.removeAt(index);
                            });
                          },
                        );

                        if (constraints.maxWidth < 320) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tipo),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(child: Text(valor)),
                                  remover,
                                ],
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: Text(tipo)),
                            Text(valor),
                            remover,
                          ],
                        );
                      },
                    ),
                  );
                }).toList(),
              ),

            const Divider(),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('Pago:'), Text(moeda(totalPago))],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('Falta:'), Text(moeda(faltaPagar))],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Troco:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  moeda(troco),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        appBar: AppTopBar(titulo: 'Vendas'),
        bottomNavigationBar: AppBottomNav(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const AppTopBar(titulo: 'Vendas'),
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: consultarVenda,
                      icon: const Icon(Icons.manage_search),
                      label: const Text('Consultar venda'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final telaEstreita = c.maxWidth < 700;

                          return Column(
                            children: [
                              campoCliente(),
                              const SizedBox(height: 12),

                              if (telaEstreita)
                                Column(
                                  children: [
                                    campoProduto(),
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: qtdController,
                                      focusNode: qtdFocus,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      decoration: const InputDecoration(
                                        labelText: 'Qtd',
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (_) => adicionarItem(),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton.icon(
                                        onPressed: adicionarItem,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Adicionar'),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: campoProduto()),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 100,
                                      child: TextField(
                                        controller: qtdController,
                                        focusNode: qtdFocus,
                                        keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        decoration: const InputDecoration(
                                          labelText: 'Qtd',
                                          border: OutlineInputBorder(),
                                        ),
                                        onSubmitted: (_) => adicionarItem(),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      height: 56,
                                      child: ElevatedButton.icon(
                                        onPressed: adicionarItem,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Adicionar'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  listaItens(),
                  const SizedBox(height: 12),
                  areaPagamentos(),

                  const SizedBox(height: 12),

                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              moeda(total),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: salvando ? null : finalizarVenda,
                      child: salvando
                          ? const CircularProgressIndicator()
                          : const Text(
                              'FINALIZAR VENDA',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ConsultaVendaDialog extends StatefulWidget {
  final VendaRepository vendaRepo;

  const ConsultaVendaDialog({super.key, required this.vendaRepo});

  @override
  State<ConsultaVendaDialog> createState() => _ConsultaVendaDialogState();
}

class _ConsultaVendaDialogState extends State<ConsultaVendaDialog> {
  final numeroController = TextEditingController();
  final motivoController = TextEditingController();
  final configReciboRepo = ConfigReciboRepository();

  Map<String, dynamic>? venda;
  bool loading = false;

  @override
  void dispose() {
    numeroController.dispose();
    motivoController.dispose();
    super.dispose();
  }

  String moeda(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String dataHora(Object? valor) {
    final data = DateTime.tryParse((valor ?? '').toString());
    if (data == null) return '';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year} '
        '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }

  Future<void> buscar() async {
    final numero = int.tryParse(numeroController.text.trim());

    if (numero == null || numero <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um numero de venda valido')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final encontrada = await widget.vendaRepo.buscarVendaPorNumero(numero);
      if (!mounted) return;
      setState(() {
        venda = encontrada;
      });

      if (encontrada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Venda nao encontrada')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> imprimir() async {
    final vendaAtual = venda;
    if (vendaAtual == null) return;

    final detalhada = await widget.vendaRepo.buscarVendaDetalhada(
      vendaAtual['id'].toString(),
    );
    final config = await configReciboRepo.buscar();

    await Printing.layoutPdf(
      name: 'recibo-venda-${detalhada['numero'] ?? detalhada['id']}.pdf',
      onLayout: (_) => ReciboVendaPdf.gerar(detalhada, config: config),
    );
  }

  Future<void> cancelar() async {
    final vendaAtual = venda;
    if (vendaAtual == null) return;

    final status = (vendaAtual['status'] ?? 'finalizada').toString();
    if (status == 'cancelada') return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar venda?'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: motivoController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo do cancelamento',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar venda'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => loading = true);

    try {
      await widget.vendaRepo.cancelarVenda(
        vendaId: vendaAtual['id'].toString(),
        motivo: motivoController.text,
      );

      final numero = int.tryParse(numeroController.text.trim());
      final atualizada = numero == null
          ? null
          : await widget.vendaRepo.buscarVendaPorNumero(numero);

      if (!mounted) return;
      setState(() {
        venda = atualizada;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venda cancelada com sucesso')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendaAtual = venda;
    final cliente = vendaAtual?['clientes'] as Map<String, dynamic>?;
    final status = (vendaAtual?['status'] ?? 'finalizada').toString();
    final cancelada = status == 'cancelada';
    final total = ((vendaAtual?['total'] as num?)?.toDouble() ?? 0);

    return AlertDialog(
      title: const Text('Consultar venda'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: numeroController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Numero da venda',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : buscar,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ),
              ],
            ),
            if (loading) const LinearProgressIndicator(),
            if (vendaAtual != null) ...[
              const SizedBox(height: 16),
              Card(
                color: cancelada ? Colors.red.shade50 : null,
                child: ListTile(
                  leading: Icon(
                    cancelada ? Icons.cancel : Icons.receipt_long,
                    color: cancelada ? Colors.red : null,
                  ),
                  title: Text(
                    'Venda ${vendaAtual['numero'] ?? ''} - '
                    '${cliente?['nome'] ?? 'Sem cliente'}',
                    style: TextStyle(
                      color: cancelada ? Colors.red : null,
                      decoration: cancelada ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${dataHora(vendaAtual['data_venda'])}\n'
                    '${cancelada ? 'Cancelada' : 'Finalizada'}',
                  ),
                  trailing: Text(
                    moeda(total),
                    style: TextStyle(
                      color: cancelada ? Colors.red : null,
                      decoration: cancelada ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Fechar'),
        ),
        if (vendaAtual != null)
          OutlinedButton.icon(
            onPressed: loading ? null : imprimir,
            icon: const Icon(Icons.print),
            label: const Text('Reimprimir'),
          ),
        if (vendaAtual != null && !cancelada)
          ElevatedButton.icon(
            onPressed: loading ? null : cancelar,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancelar venda'),
          ),
      ],
    );
  }
}
