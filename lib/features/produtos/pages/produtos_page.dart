// lib/features/produtos/pages/produtos_page.dart

import 'package:flutter/material.dart';
import '../models/produto_model.dart';
import '../repositories/produto_repository.dart';
import '../widgets/produto_form_dialog.dart';
import '../../../core/widgets/app_top_bar.dart';

enum TipoOrdenacao { codigo, descricao, estoque, venda }
enum FiltroStatusProduto { ativos, todos, inativos }

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  final repository = ProdutoRepository();

  final buscaController = TextEditingController();
  final tabelaVerticalController = ScrollController();
  final tabelaHorizontalController = ScrollController();

  String busca = '';

  bool crescente = true;
  FiltroStatusProduto filtroStatus = FiltroStatusProduto.ativos;

  TipoOrdenacao ordenarPor = TipoOrdenacao.codigo;

  @override
  void dispose() {
    buscaController.dispose();
    tabelaVerticalController.dispose();
    tabelaHorizontalController.dispose();
    super.dispose();
  }

  Future<void> abrirModalNovoProduto() async {
    final resultado = await showDialog(
      context: context,
      builder: (_) => const ProdutoFormDialog(),
    );

    if (resultado == true) {
      setState(() {});
    }
  }

  bool get incluirInativos => filtroStatus == FiltroStatusProduto.todos;
  bool get somenteInativos => filtroStatus == FiltroStatusProduto.inativos;

  Future<void> excluirOuInativar(Produto produto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text(
          'Vamos tentar excluir ${produto.descricao}. Se ele ja estiver vinculado a vendas ou movimentacoes, o historico sera preservado e voce podera inativa-lo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final excluiu = await repository.excluir(produto.id);
      if (!mounted) return;

      if (excluiu) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto excluido com sucesso')),
        );
        setState(() {});
        return;
      }

      final inativar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Nao foi possivel excluir'),
          content: const Text(
            'Este produto ja possui relacionamento no banco de dados, como vendas ou movimentacoes de estoque. Para preservar o historico, ele nao pode ser excluido. Inative o produto para remove-lo das novas vendas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter ativo'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Inativar produto'),
            ),
          ],
        ),
      );

      if (inativar == true) {
        await repository.inativar(produto.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto inativado com sucesso')),
        );
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel excluir o produto')),
      );
    }
  }

  Future<void> abrirMovimentacao(Produto produto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => MovimentacaoEstoqueDialog(produto: produto),
    );

    if (ok == true) setState(() {});
  }

  String normalizar(String texto) {
    const com = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    const sem = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

    for (int i = 0; i < com.length; i++) {
      texto = texto.replaceAll(com[i], sem[i]);
    }

    return texto.toLowerCase();
  }

  void trocarOrdenacao(TipoOrdenacao tipo) {
    setState(() {
      if (ordenarPor == tipo) {
        crescente = !crescente;
      } else {
        ordenarPor = tipo;
        crescente = true;
      }
    });
  }

  List<Produto> processarLista(List<Produto> lista) {
    final texto = normalizar(busca.trim());

    var filtrada = lista.where((p) {
      if (texto.isEmpty) {
        return true;
      }

      final cod = normalizar(p.codigo);

      final desc = normalizar(p.descricao);

      return cod.contains(texto) || desc.contains(texto);
    }).toList();

    filtrada.sort((a, b) {
      dynamic valorA;
      dynamic valorB;

      switch (ordenarPor) {
        case TipoOrdenacao.codigo:
          valorA = int.tryParse(a.codigo) ?? 0;
          valorB = int.tryParse(b.codigo) ?? 0;
          break;

        case TipoOrdenacao.descricao:
          valorA = normalizar(a.descricao);
          valorB = normalizar(b.descricao);
          break;

        case TipoOrdenacao.estoque:
          valorA = a.estoqueAtual;
          valorB = b.estoqueAtual;
          break;

        case TipoOrdenacao.venda:
          valorA = a.precoVenda;
          valorB = b.precoVenda;
          break;
      }

      int resultado = valorA.compareTo(valorB);

      if (!crescente) {
        resultado = -resultado;
      }

      return resultado;
    });

    if (texto.isNotEmpty && ordenarPor == TipoOrdenacao.descricao) {
      filtrada.sort((a, b) {
        final descA = normalizar(a.descricao);
        final descB = normalizar(b.descricao);

        final aComeca = descA.startsWith(texto);
        final bComeca = descB.startsWith(texto);

        if (aComeca && !bComeca) {
          return -1;
        }

        if (!aComeca && bComeca) {
          return 1;
        }

        return 0;
      });
    }

    return filtrada;
  }

  Icon iconeOrdenacao(TipoOrdenacao tipo) {
    if (ordenarPor != tipo) {
      return const Icon(Icons.unfold_more, size: 16);
    }

    return Icon(
      crescente ? Icons.arrow_upward : Icons.arrow_downward,
      size: 16,
    );
  }

  Widget cabecalho(String texto, TipoOrdenacao tipo) {
    return InkWell(
      onTap: () => trocarOrdenacao(tipo),
      child: Row(
        children: [Text(texto), const SizedBox(width: 4), iconeOrdenacao(tipo)],
      ),
    );
  }

  Widget tabela(List<Produto> produtos) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.hardEdge,
      child: Scrollbar(
        controller: tabelaVerticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: tabelaVerticalController,
          primary: false,
          child: Scrollbar(
            controller: tabelaHorizontalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: tabelaHorizontalController,
              primary: false,
              scrollDirection: Axis.horizontal,
              child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          columns: [
            DataColumn(label: cabecalho('Código', TipoOrdenacao.codigo)),
            DataColumn(label: cabecalho('Produto', TipoOrdenacao.descricao)),
            DataColumn(label: cabecalho('Estoque', TipoOrdenacao.estoque)),
            const DataColumn(label: Text('Custo')),
            DataColumn(label: cabecalho('Venda', TipoOrdenacao.venda)),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Ações')),
          ],
          rows: produtos.map((p) {
            return DataRow(
              color: !p.ativo
                  ? WidgetStateProperty.all(Colors.grey.shade100)
                  : null,
              cells: [
                DataCell(Text(p.codigo)),
                DataCell(Text(p.descricao)),
                DataCell(Text(p.estoqueAtual.toStringAsFixed(0))),
                DataCell(Text('R\$ ${p.precoCusto.toStringAsFixed(2)}')),
                DataCell(Text('R\$ ${p.precoVenda.toStringAsFixed(2)}')),
                DataCell(
                  Text(
                    p.ativo ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      color: p.ativo ? Colors.green.shade700 : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final ok = await showDialog(
                            context: context,
                            builder: (_) => ProdutoFormDialog(produto: p),
                          );

                          if (ok == true) {
                            setState(() {});
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Movimentar estoque',
                        icon: const Icon(Icons.swap_vert),
                        onPressed: () => abrirMovimentacao(p),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        onPressed: () => excluirOuInativar(p),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget listaMobile(List<Produto> produtos) {
    return ListView.builder(
      itemCount: produtos.length,
      itemBuilder: (context, index) {
        final p = produtos[index];

        return Card(
          color: p.ativo ? null : Colors.grey.shade100,
          child: ListTile(
            leading: p.ativo
                ? null
                : const Icon(Icons.block, color: Colors.red),
            title: Text(p.descricao),
            subtitle: Text(
              'Código: ${p.codigo}\nEstoque: ${p.estoqueAtual.toStringAsFixed(0)}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'editar') {
                  showDialog(
                    context: context,
                    builder: (_) => ProdutoFormDialog(produto: p),
                  ).then((ok) {
                    if (ok == true) setState(() {});
                  });
                }
                if (value == 'movimentar') abrirMovimentacao(p);
                if (value == 'excluir') excluirOuInativar(p);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                  value: 'movimentar',
                  child: Text('Movimentar estoque'),
                ),
                PopupMenuItem(value: 'excluir', child: Text('Excluir')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;

    final desktop = largura > 700;

    return Scaffold(
      appBar: const AppTopBar(titulo: 'Produtos'),
      bottomNavigationBar: const AppBottomNav(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final filtroStatusWidget = SegmentedButton<FiltroStatusProduto>(
                  segments: const [
                    ButtonSegment(
                      value: FiltroStatusProduto.ativos,
                      label: Text('Ativos'),
                    ),
                    ButtonSegment(
                      value: FiltroStatusProduto.todos,
                      label: Text('Todos'),
                    ),
                    ButtonSegment(
                      value: FiltroStatusProduto.inativos,
                      label: Text('Inativos'),
                    ),
                  ],
                  selected: {filtroStatus},
                  onSelectionChanged: (value) {
                    setState(() {
                      filtroStatus = value.first;
                    });
                  },
                );

                final campoBusca = TextField(
                  controller: buscaController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar produto...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      busca = value;
                    });
                  },
                );

                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      campoBusca,
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: filtroStatusWidget,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: campoBusca),
                    const SizedBox(width: 12),
                    filtroStatusWidget,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Produto>>(
                future: repository.buscarTodos(
                  incluirInativos: incluirInativos,
                  somenteInativos: somenteInativos,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final lista = processarLista(snapshot.data!);

                  if (lista.isEmpty) {
                    return const Center(
                      child: Text('Nenhum produto encontrado'),
                    );
                  }

                  return desktop ? tabela(lista) : listaMobile(lista);
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirModalNovoProduto,
        icon: const Icon(Icons.add),
        label: const Text('Novo Produto'),
      ),
    );
  }
}

class MovimentacaoEstoqueDialog extends StatefulWidget {
  final Produto produto;

  const MovimentacaoEstoqueDialog({super.key, required this.produto});

  @override
  State<MovimentacaoEstoqueDialog> createState() =>
      _MovimentacaoEstoqueDialogState();
}

class _MovimentacaoEstoqueDialogState
    extends State<MovimentacaoEstoqueDialog> {
  final repository = ProdutoRepository();
  final quantidadeController = TextEditingController();
  final observacaoController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String tipo = 'entrada';
  bool loading = false;

  @override
  void dispose() {
    quantidadeController.dispose();
    observacaoController.dispose();
    super.dispose();
  }

  double parseNumero(String valor) {
    return double.tryParse(valor.replaceAll(',', '.').trim()) ?? 0;
  }

  Future<void> salvar() async {
    if (!formKey.currentState!.validate()) return;

    try {
      setState(() => loading = true);

      await repository.movimentarEstoque(
        produto: widget.produto,
        tipo: tipo,
        quantidade: parseNumero(quantidadeController.text),
        observacao: observacaoController.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nao foi possivel registrar a movimentacao'),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estoqueAtual = widget.produto.estoqueAtual.toStringAsFixed(0);

    return AlertDialog(
      title: const Text('Movimentar estoque'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.produto.descricao,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Estoque atual: $estoqueAtual'),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'entrada', label: Text('Entrada')),
                  ButtonSegment(value: 'saida', label: Text('Saida')),
                ],
                selected: {tipo},
                onSelectionChanged: (value) {
                  setState(() {
                    tipo = value.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: quantidadeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final quantidade = parseNumero(value ?? '');
                  if (quantidade <= 0) return 'Informe uma quantidade valida';
                  if (tipo == 'saida' && quantidade > widget.produto.estoqueAtual) {
                    return 'A saida nao pode deixar estoque negativo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: observacaoController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observacao',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: loading ? null : salvar,
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
