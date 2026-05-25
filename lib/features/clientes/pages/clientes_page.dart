import 'package:flutter/material.dart';

import '../../../core/telefone_utils.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../models/cliente_model.dart';
import '../repositories/cliente_repository.dart';
import '../widgets/cliente_form_dialog.dart';

enum FiltroStatusCliente { ativos, todos, inativos }

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final repo = ClienteRepository();
  final buscaController = TextEditingController();

  String busca = '';
  FiltroStatusCliente filtroStatus = FiltroStatusCliente.ativos;

  @override
  void dispose() {
    buscaController.dispose();
    super.dispose();
  }

  Future<void> abrirNovo() async {
    final ok = await showDialog(
      context: context,
      builder: (_) => const ClienteFormDialog(),
    );

    if (ok == true) setState(() {});
  }

  Future<void> editar(Cliente cliente) async {
    final ok = await showDialog(
      context: context,
      builder: (_) => ClienteFormDialog(cliente: cliente),
    );

    if (ok == true) setState(() {});
  }

  Future<void> excluirOuInativar(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir cliente?'),
        content: Text(
          'Vamos tentar excluir ${cliente.nome}. Se ele ja tiver vendas vinculadas, o historico sera preservado e voce podera inativa-lo.',
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
      final excluiu = await repo.excluir(cliente.id);
      if (!mounted) return;

      if (excluiu) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente excluido com sucesso')),
        );
        setState(() {});
        return;
      }

      final inativar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Nao foi possivel excluir'),
          content: const Text(
            'Este cliente ja possui relacionamento no banco de dados, como vendas. Para preservar o historico, ele nao pode ser excluido. Inative o cadastro para impedir novas vendas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Manter ativo'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Inativar cliente'),
            ),
          ],
        ),
      );

      if (inativar == true) {
        await repo.inativar(cliente.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente inativado com sucesso')),
        );
        setState(() {});
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel excluir o cliente')),
      );
    }
  }

  bool get incluirInativos => filtroStatus == FiltroStatusCliente.todos;
  bool get somenteInativos => filtroStatus == FiltroStatusCliente.inativos;

  String formatarCpfCnpj(String valor) {
    final numeros = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length == 11) {
      return '${numeros.substring(0, 3)}.'
          '${numeros.substring(3, 6)}.'
          '${numeros.substring(6, 9)}-'
          '${numeros.substring(9)}';
    }

    if (numeros.length == 14) {
      return '${numeros.substring(0, 2)}.'
          '${numeros.substring(2, 5)}.'
          '${numeros.substring(5, 8)}/'
          '${numeros.substring(8, 12)}-'
          '${numeros.substring(12)}';
    }

    return valor;
  }

  String norm(String t) {
    const a = 'áàãâäéèêëíìîïóòõôöúùûüçÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇ';
    const b = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';

    for (int i = 0; i < a.length; i++) {
      t = t.replaceAll(a[i], b[i]);
    }

    return t.toLowerCase();
  }

  List<Cliente> filtrar(List<Cliente> lista) {
    final texto = norm(busca.trim());
    final numeros = busca.replaceAll(RegExp(r'[^0-9]'), '');

    if (texto.isEmpty && numeros.isEmpty) return lista;

    return lista.where((c) {
      final dados = [
        c.nome,
        c.telefone,
        c.endereco,
        c.referencia,
        c.cpfCnpj,
      ].map(norm).join(' ');

      final numerosCliente = '${c.telefone} ${c.cpfCnpj}'.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      return dados.contains(texto) ||
          (numeros.isNotEmpty && numerosCliente.contains(numeros));
    }).toList();
  }

  Widget tabela(List<Cliente> lista) {
    return Card(
      elevation: 3,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nome')),
            DataColumn(label: Text('CPF/CNPJ')),
            DataColumn(label: Text('Telefone')),
            DataColumn(label: Text('Endereco')),
            DataColumn(label: Text('Referencia')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Acoes')),
          ],
          rows: lista.map((c) {
            return DataRow(
              color: !c.ativo
                  ? WidgetStateProperty.all(Colors.grey.shade100)
                  : null,
              cells: [
                DataCell(Text(c.nome)),
                DataCell(Text(formatarCpfCnpj(c.cpfCnpj))),
                DataCell(Text(formatarTelefone(c.telefone))),
                DataCell(Text(c.endereco)),
                DataCell(Text(c.referencia)),
                DataCell(
                  Text(
                    c.ativo ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      color: c.ativo ? Colors.green.shade700 : Colors.red,
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
                        onPressed: () => editar(c),
                      ),
                      IconButton(
                        tooltip: 'Excluir',
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        onPressed: () => excluirOuInativar(c),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget listaMobile(List<Cliente> lista) {
    return ListView.builder(
      itemCount: lista.length,
      itemBuilder: (context, i) {
        final c = lista[i];

        return Card(
          color: c.ativo ? null : Colors.grey.shade100,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            title: Text(
              c.nome,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: c.ativo ? null : Colors.red,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${formatarTelefone(c.telefone)}\n'
                '${formatarCpfCnpj(c.cpfCnpj)}\n'
                '${c.endereco}\n'
                '${c.ativo ? 'Ativo' : 'Inativo'}',
              ),
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => editar(c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  onPressed: () => excluirOuInativar(c),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget filtros() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final campoBusca = TextField(
          controller: buscaController,
          onChanged: (v) {
            setState(() {
              busca = v;
            });
          },
          decoration: InputDecoration(
            hintText:
                'Buscar por nome, telefone, CPF, endereco ou referencia...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        final filtro = SegmentedButton<FiltroStatusCliente>(
          segments: const [
            ButtonSegment(
              value: FiltroStatusCliente.ativos,
              label: Text('Ativos'),
            ),
            ButtonSegment(
              value: FiltroStatusCliente.todos,
              label: Text('Todos'),
            ),
            ButtonSegment(
              value: FiltroStatusCliente.inativos,
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

        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              campoBusca,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: filtro,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: campoBusca),
            const SizedBox(width: 12),
            filtro,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: const AppTopBar(titulo: 'Clientes'),
      bottomNavigationBar: const AppBottomNav(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            filtros(),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Cliente>>(
                future: repo.buscarTodos(
                  incluirInativos: incluirInativos,
                  somenteInativos: somenteInativos,
                ),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final lista = filtrar(snapshot.data!);

                  if (lista.isEmpty) {
                    return const Center(
                      child: Text('Nenhum cliente encontrado'),
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
        onPressed: abrirNovo,
        icon: const Icon(Icons.add),
        label: const Text('Novo Cliente'),
      ),
    );
  }
}
