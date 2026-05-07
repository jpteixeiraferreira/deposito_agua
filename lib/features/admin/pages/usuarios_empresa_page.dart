import 'package:flutter/material.dart';

import '../../../core/widgets/app_top_bar.dart';
import '../repositories/admin_repository.dart';

class UsuariosEmpresaPage extends StatefulWidget {
  final String? empresaId;
  final String titulo;

  const UsuariosEmpresaPage({
    super.key,
    this.empresaId,
    this.titulo = 'Usuarios',
  });

  @override
  State<UsuariosEmpresaPage> createState() => _UsuariosEmpresaPageState();
}

class _UsuariosEmpresaPageState extends State<UsuariosEmpresaPage> {
  final repo = AdminRepository();

  Future<void> novoUsuario() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => NovoUsuarioDialog(empresaId: widget.empresaId),
    );

    if (ok == true) setState(() {});
  }

  Future<void> editarUsuario(Map<String, dynamic> usuario) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => EditarUsuarioDialog(usuario: usuario),
    );

    if (ok == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(titulo: widget.titulo),
      bottomNavigationBar: const AppBottomNav(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: novoUsuario,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo usuario'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.buscarUsuariosEmpresa(empresaId: widget.empresaId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final usuarios = snapshot.data!;
          if (usuarios.isEmpty) {
            return const Center(child: Text('Nenhum usuario cadastrado'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              final ativo = usuario['ativo'] as bool? ?? true;
              final nome = usuario['nome']?.toString();
              final email = usuario['email']?.toString();
              final papel = usuario['papel']?.toString() ?? 'operador';

              return Card(
                child: ListTile(
                  leading: Icon(
                    ativo ? Icons.person : Icons.person_off,
                    color: ativo ? Colors.green : Colors.red,
                  ),
                  title: Text(nome?.isNotEmpty == true ? nome! : email ?? ''),
                  subtitle: Text('${email ?? ''}\n${_nomePapel(papel)}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Editar permissao',
                    icon: const Icon(Icons.manage_accounts),
                    onPressed: () => editarUsuario(usuario),
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

class NovoUsuarioDialog extends StatefulWidget {
  final String? empresaId;

  const NovoUsuarioDialog({super.key, this.empresaId});

  @override
  State<NovoUsuarioDialog> createState() => _NovoUsuarioDialogState();
}

class _NovoUsuarioDialogState extends State<NovoUsuarioDialog> {
  final repo = AdminRepository();
  final formKey = GlobalKey<FormState>();
  final nome = TextEditingController();
  final email = TextEditingController();
  final senha = TextEditingController();
  String papel = 'operador';
  bool loading = false;

  @override
  void dispose() {
    nome.dispose();
    email.dispose();
    senha.dispose();
    super.dispose();
  }

  Future<void> salvar() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      await repo.criarUsuarioEmpresa(
        empresaId: widget.empresaId,
        nome: nome.text.trim(),
        email: email.text.trim(),
        senha: senha.text,
        papel: papel,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel criar o usuario')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo usuario'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campoUsuario('Nome', nome),
              _campoUsuario('E-mail', email, tipo: TextInputType.emailAddress),
              _campoUsuario('Senha inicial', senha, obscure: true),
              DropdownButtonFormField<String>(
                initialValue: papel,
                decoration: const InputDecoration(
                  labelText: 'Permissao',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'gerente', child: Text('Gerente')),
                  DropdownMenuItem(value: 'operador', child: Text('Operador')),
                  DropdownMenuItem(value: 'consulta', child: Text('Consulta')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => papel = value);
                },
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
              : const Text('Criar'),
        ),
      ],
    );
  }
}

class EditarUsuarioDialog extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const EditarUsuarioDialog({super.key, required this.usuario});

  @override
  State<EditarUsuarioDialog> createState() => _EditarUsuarioDialogState();
}

class _EditarUsuarioDialogState extends State<EditarUsuarioDialog> {
  final repo = AdminRepository();
  late String papel;
  late bool ativo;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    papel = widget.usuario['papel']?.toString() ?? 'operador';
    ativo = widget.usuario['ativo'] as bool? ?? true;
  }

  Future<void> salvar() async {
    setState(() => loading = true);
    try {
      await repo.atualizarUsuarioEmpresa(
        userId: widget.usuario['user_id'].toString(),
        empresaId: widget.usuario['empresa_id'].toString(),
        papel: papel,
        ativo: ativo,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nao foi possivel atualizar o usuario')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.usuario['email']?.toString() ?? 'Usuario'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: papel,
              decoration: const InputDecoration(
                labelText: 'Permissao',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'gerente', child: Text('Gerente')),
                DropdownMenuItem(value: 'operador', child: Text('Operador')),
                DropdownMenuItem(value: 'consulta', child: Text('Consulta')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => papel = value);
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: ativo,
              contentPadding: EdgeInsets.zero,
              title: const Text('Usuario ativo'),
              onChanged: (value) => setState(() => ativo = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: loading ? null : salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

Widget _campoUsuario(
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
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Campo obrigatorio';
        return null;
      },
    ),
  );
}

String _nomePapel(String papel) {
  switch (papel) {
    case 'admin':
      return 'Admin';
    case 'gerente':
      return 'Gerente';
    case 'consulta':
      return 'Consulta';
    default:
      return 'Operador';
  }
}
