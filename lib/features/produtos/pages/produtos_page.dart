// lib/features/produtos/pages/produtos_page.dart

import 'package:flutter/material.dart';
import '../models/produto_model.dart';
import '../repositories/produto_repository.dart';
import '../widgets/produto_form_dialog.dart';
import '../../../core/widgets/app_top_bar.dart';

enum TipoOrdenacao { codigo, descricao, estoque, venda }

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  final repository = ProdutoRepository();

  final buscaController = TextEditingController();

  String busca = '';

  bool crescente = true;

  TipoOrdenacao ordenarPor = TipoOrdenacao.codigo;

  Future<void> abrirModalNovoProduto() async {
    final resultado = await showDialog(
      context: context,
      builder: (_) => const ProdutoFormDialog(),
    );

    if (resultado == true) {
      setState(() {});
    }
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          columns: [
            DataColumn(label: cabecalho('Código', TipoOrdenacao.codigo)),
            DataColumn(label: cabecalho('Produto', TipoOrdenacao.descricao)),
            DataColumn(label: cabecalho('Estoque', TipoOrdenacao.estoque)),
            const DataColumn(label: Text('Custo')),
            DataColumn(label: cabecalho('Venda', TipoOrdenacao.venda)),
            const DataColumn(label: Text('Ações')),
          ],
          rows: produtos.map((p) {
            return DataRow(
              cells: [
                DataCell(Text(p.codigo)),
                DataCell(Text(p.descricao)),
                DataCell(Text(p.estoqueAtual.toStringAsFixed(0))),
                DataCell(Text('R\$ ${p.precoCusto.toStringAsFixed(2)}')),
                DataCell(Text('R\$ ${p.precoVenda.toStringAsFixed(2)}')),
                DataCell(
                  IconButton(
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
                ),
              ],
            );
          }).toList(),
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
          child: ListTile(
            title: Text(p.descricao),
            subtitle: Text(
              'Código: ${p.codigo}\nEstoque: ${p.estoqueAtual.toStringAsFixed(0)}',
            ),
            trailing: Text('R\$ ${p.precoVenda.toStringAsFixed(2)}'),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
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
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Produto>>(
                future: repository.buscarTodos(),
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
