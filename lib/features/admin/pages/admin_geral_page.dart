import 'package:flutter/material.dart';

import '../../../core/widgets/app_top_bar.dart';
import '../repositories/admin_repository.dart';
import 'usuarios_empresa_page.dart';

class AdminGeralPage extends StatefulWidget {
  const AdminGeralPage({super.key});

  @override
  State<AdminGeralPage> createState() => _AdminGeralPageState();
}

class _AdminGeralPageState extends State<AdminGeralPage> {
  final repo = AdminRepository();

  Future<void> abrirNovaEmpresa() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const NovaEmpresaDialog(),
    );

    if (ok == true) setState(() {});
  }

  Future<void> abrirUsuarios(Map<String, dynamic> empresa) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UsuariosDaEmpresaSelecionadaPage(
          empresaId: empresa['id'].toString(),
          nomeEmpresa: empresa['nome']?.toString() ?? 'Empresa',
        ),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(titulo: 'Admin geral'),
      bottomNavigationBar: const AppBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirNovaEmpresa,
        icon: const Icon(Icons.business),
        label: const Text('Nova empresa'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.buscarEmpresas(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final empresas = snapshot.data!;
          if (empresas.isEmpty) {
            return const Center(child: Text('Nenhuma empresa cadastrada'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: empresas.length,
            itemBuilder: (context, index) {
              final empresa = empresas[index];
              final ativa = empresa['ativo'] as bool? ?? true;

              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.business,
                    color: ativa ? Colors.green : Colors.red,
                  ),
                  title: Text(empresa['nome']?.toString() ?? 'Empresa'),
                  subtitle: Text(ativa ? 'Ativa' : 'Inativa'),
                  trailing: IconButton(
                    tooltip: 'Usuarios',
                    icon: const Icon(Icons.people),
                    onPressed: () => abrirUsuarios(empresa),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class NovaEmpresaDialog extends StatefulWidget {
  const NovaEmpresaDialog({super.key});

  @override
  State<NovaEmpresaDialog> createState() => _NovaEmpresaDialogState();
}

class _NovaEmpresaDialogState extends State<NovaEmpresaDialog> {
  final repo = AdminRepository();
  final formKey = GlobalKey<FormState>();
  final nomeEmpresa = TextEditingController();
  final nomeUsuario = TextEditingController();
  final email = TextEditingController();
  final senha = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    nomeEmpresa.dispose();
    nomeUsuario.dispose();
    email.dispose();
    senha.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      await repo.criarEmpresaComAdmin(
        nomeEmpresa: nomeEmpresa.text.trim(),
        nomeUsuario: nomeUsuario.text.trim(),
        email: email.text.trim(),
        senha: senha.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel criar a empresa')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova empresa'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campo('Nome da empresa', nomeEmpresa),
              _campo('Nome do admin', nomeUsuario),
              _campo('E-mail do admin', email, tipo: TextInputType.emailAddress),
              _campo('Senha inicial', senha, obscure: true),
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
              : const Text('Criar'),
        ),
      ],
    );
  }
}

Widget _campo(
  String label,
  TextEditingController controller, {
  TextInputType? tipo,
  bool obscure = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: tipo,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Campo obrigatorio';
        return null;
      },
    ),
  );
}

class UsuariosDaEmpresaSelecionadaPage extends StatelessWidget {
  final String empresaId;
  final String nomeEmpresa;

  const UsuariosDaEmpresaSelecionadaPage({
    super.key,
    required this.empresaId,
    required this.nomeEmpresa,
  });

  @override
  Widget build(BuildContext context) {
    return UsuariosEmpresaPage(
      empresaId: empresaId,
      titulo: 'Usuarios - $nomeEmpresa',
    );
  }
}
