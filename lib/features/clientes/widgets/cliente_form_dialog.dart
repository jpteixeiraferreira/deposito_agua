import 'package:flutter/material.dart';
import '../models/cliente_model.dart';
import '../repositories/cliente_repository.dart';

class ClienteFormDialog extends StatefulWidget {
  final Cliente? cliente;

  const ClienteFormDialog({super.key, this.cliente});

  @override
  State<ClienteFormDialog> createState() => _ClienteFormDialogState();
}

class _ClienteFormDialogState extends State<ClienteFormDialog> {
  final repo = ClienteRepository();

  final formKey = GlobalKey<FormState>();

  final nome = TextEditingController();

  final telefone = TextEditingController();

  final endereco = TextEditingController();

  final referencia = TextEditingController();

  final cpfCnpj = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.cliente != null) {
      nome.text = widget.cliente!.nome;

      telefone.text = widget.cliente!.telefone;

      endereco.text = widget.cliente!.endereco;

      referencia.text = widget.cliente!.referencia;

      cpfCnpj.text = widget.cliente!.cpfCnpj;
    }
  }

  Future<void> salvar() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() => loading = true);

      if (widget.cliente == null) {
        await repo.inserir(
          nome: nome.text.trim(),
          telefone: telefone.text.trim(),
          endereco: endereco.text.trim(),
          referencia: referencia.text.trim(),
          cpfCnpj: cpfCnpj.text.trim(),
        );
      } else {
        await repo.atualizar(
          id: widget.cliente!.id,
          nome: nome.text.trim(),
          telefone: telefone.text.trim(),
          endereco: endereco.text.trim(),
          referencia: referencia.text.trim(),
          cpfCnpj: cpfCnpj.text.trim(),
        );
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao salvar cliente')));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  InputDecoration deco(String texto) {
    return InputDecoration(
      labelText: texto,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget campo({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? tipo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: tipo,
        decoration: deco(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cliente == null ? 'Novo Cliente' : 'Editar Cliente'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                campo(
                  label: 'Nome',
                  controller: nome,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o nome';
                    }
                    return null;
                  },
                ),

                campo(
                  label: 'Telefone',
                  controller: telefone,
                  tipo: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o telefone';
                    }
                    return null;
                  },
                ),

                campo(label: 'Endereço', controller: endereco),

                campo(label: 'Referência', controller: referencia),

                campo(label: 'CPF/CNPJ', controller: cpfCnpj),
              ],
            ),
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
