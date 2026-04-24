// lib/features/produtos/widgets/produto_form_dialog.dart

import 'package:flutter/material.dart';
import '../repositories/produto_repository.dart';
import '../models/produto_model.dart';

class ProdutoFormDialog extends StatefulWidget {
  final Produto? produto;
  const ProdutoFormDialog({super.key, this.produto});

  @override
  State<ProdutoFormDialog> createState() => _ProdutoFormDialogState();
}

class _ProdutoFormDialogState extends State<ProdutoFormDialog> {
  final repo = ProdutoRepository();
  final formKey = GlobalKey<FormState>();

  final descricao = TextEditingController();
  final precoCusto = TextEditingController();
  final precoVenda = TextEditingController();
  final estoque = TextEditingController();

  bool loading = false;

  double parseNumero(String valor) {
    return double.tryParse(valor.replaceAll(',', '.').trim()) ?? 0;
  }

  Future<void> salvar() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    try {
      setState(() => loading = true);

      if (widget.produto == null) {
        final codigo = await repo.gerarProximoCodigo();

        await repo.inserir(
          codigo: codigo,
          descricao: descricao.text.trim(),
          precoCusto: parseNumero(precoCusto.text),
          precoVenda: parseNumero(precoVenda.text),
          estoqueInicial: parseNumero(estoque.text),
        );
      } else {
        await repo.atualizar(
          id: widget.produto!.id,
          descricao: descricao.text.trim(),
          precoCusto: parseNumero(precoCusto.text),
          precoVenda: parseNumero(precoVenda.text),
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
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

  Widget campoTexto({
    required String label,
    required TextEditingController controller,
    TextInputType? tipo,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        validator: validator,
        decoration: deco(label),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.produto != null) {
      descricao.text = widget.produto!.descricao;

      precoCusto.text = widget.produto!.precoCusto.toString();

      precoVenda.text = widget.produto!.precoVenda.toString();

      estoque.text = widget.produto!.estoqueAtual.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.produto == null ? 'Novo Produto' : 'Editar Produto'),

      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                campoTexto(
                  label: 'Descrição',
                  controller: descricao,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe a descrição';
                    }
                    return null;
                  },
                ),

                campoTexto(
                  label: 'Preço de Custo',
                  controller: precoCusto,
                  tipo: TextInputType.number,
                ),

                campoTexto(
                  label: 'Preço de Venda',
                  controller: precoVenda,
                  tipo: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o preço';
                    }
                    return null;
                  },
                ),
                if (widget.produto == null)
                  campoTexto(
                    label: 'Estoque Inicial',
                    controller: estoque,
                    tipo: TextInputType.number,
                  ),
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
