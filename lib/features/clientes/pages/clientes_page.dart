import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../repositories/cliente_repository.dart';
import '../widgets/cliente_form_dialog.dart';
import '../../../core/widgets/app_top_bar.dart';

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

  String formatarTelefone(String valor) {
    final numeros = valor.replaceAll(RegExp(r'[^0-9]'), '');

    if (numeros.length == 10) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 6)}-'
          '${numeros.substring(6)}';
    }

    if (numeros.length == 11) {
      return '(${numeros.substring(0, 2)}) '
          '${numeros.substring(2, 7)}-'
          '${numeros.substring(7)}';
    }

    return valor;
  }

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

    if (texto.isEmpty) {
      return lista;
    }

    return lista.where((c) {
      final nome = norm(c.nome);

      final telefone = norm(c.telefone);

      final endereco = norm(c.endereco);

      final referencia = norm(c.referencia);

      final cpf = norm(c.cpfCnpj);

      return nome.contains(texto) ||
          telefone.contains(texto) ||
          endereco.contains(texto) ||
          referencia.contains(texto) ||
          cpf.contains(texto);
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
            DataColumn(label: Text('Endereço')),
            DataColumn(label: Text('Referência')),
            DataColumn(label: Text('Ações')),
          ],
          rows: lista.map((c) {
            return DataRow(
              cells: [
                DataCell(Text(c.nome)),
                DataCell(Text(formatarCpfCnpj(c.cpfCnpj))),
                DataCell(Text(formatarTelefone(c.telefone))),
                DataCell(Text(c.endereco)),
                DataCell(Text(c.referencia)),
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
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),

            title: Text(
              c.nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${formatarTelefone(c.telefone)}\n'
                '${formatarCpfCnpj(c.cpfCnpj)}\n'
                '${c.endereco}',
              ),
            ),

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
      appBar: const AppTopBar(titulo: 'Clientes'),
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
                hintText:
                    'Buscar por nome, telefone, CPF, endereço ou referência...',
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
