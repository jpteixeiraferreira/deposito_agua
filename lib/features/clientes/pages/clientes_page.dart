import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../repositories/cliente_repository.dart';
import '../widgets/cliente_form_dialog.dart';

class ClientesPage extends StatefulWidget {
  const ClientesPage({super.key});

  @override
  State<ClientesPage> createState() => _ClientesPageState();
}

class _ClientesPageState extends State<ClientesPage> {
  final repo = ClienteRepository();

  final buscaController = TextEditingController();

  String busca = '';

  Future<void> abrirNovo() async {
    final ok = await showDialog(
      context: context,
      builder: (_) => const ClienteFormDialog(),
    );

    if (ok == true) {
      setState(() {});
    }
  }

  Future<void> editar(Cliente cliente) async {
    final ok = await showDialog(
      context: context,
      builder: (_) => ClienteFormDialog(cliente: cliente),
    );

    if (ok == true) {
      setState(() {});
    }
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

    if (texto.isEmpty) {
      return lista;
    }

    return lista.where((c) {
      final nome = norm(c.nome);

      final tel = norm(c.telefone);

      return nome.contains(texto) || tel.contains(texto);
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
            DataColumn(label: Text('Telefone')),
            DataColumn(label: Text('Endereço')),
            DataColumn(label: Text('Ações')),
          ],
          rows: lista.map((c) {
            return DataRow(
              cells: [
                DataCell(Text(c.nome)),
                DataCell(Text(c.telefone)),
                DataCell(Text(c.endereco)),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => editar(c),
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
          child: ListTile(
            title: Text(c.nome),
            subtitle: Text('${c.telefone}\n${c.endereco}'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => editar(c),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: buscaController,
              onChanged: (v) {
                setState(() {
                  busca = v;
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Cliente>>(
                future: repo.buscarTodos(),
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
