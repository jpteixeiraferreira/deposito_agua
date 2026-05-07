import 'package:flutter/material.dart';

import '../models/produto_model.dart';
import '../repositories/produto_repository.dart';

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
  bool ativo = true;

  double parseNumero(String valor) {
    final texto = valor.trim();
    if (texto.isEmpty) return 0;

    if (texto.contains(',') && texto.contains('.')) {
      return double.tryParse(texto.replaceAll('.', '').replaceAll(',', '.')) ??
          0;
    }

    return double.tryParse(texto.replaceAll(',', '.')) ?? 0;
  }

  bool validarRegraPrecos() {
    final custo = parseNumero(precoCusto.text);
    final venda = parseNumero(precoVenda.text);

    if (venda <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O preco de venda deve ser maior que zero'),
        ),
      );
      return false;
    }

    if (custo > venda) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O custo nao pode ser maior que o preco de venda'),
        ),
      );
      return false;
    }

    return true;
  }

  String? validarPrecoCusto(String? valor) {
    final custo = parseNumero(valor ?? '');
    final venda = parseNumero(precoVenda.text);

    if (custo < 0) return 'O custo nao pode ser negativo';

    if (precoVenda.text.trim().isNotEmpty && custo > venda) {
      return 'O custo nao pode ser maior que o preco de venda';
    }

    return null;
  }

  String? validarPrecoVenda(String? valor) {
    final venda = parseNumero(valor ?? '');
    final custo = parseNumero(precoCusto.text);

    if ((valor ?? '').trim().isEmpty) return 'Informe o preco de venda';
    if (venda <= 0) return 'O preco de venda deve ser maior que zero';

    if (custo > venda) {
      return 'O custo nao pode ser maior que o preco de venda';
    }

    return null;
  }

  Future<void> salvar() async {
    if (!formKey.currentState!.validate()) return;
    if (!validarRegraPrecos()) return;

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
          ativo: ativo,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message.toString())));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
    } finally {
      if (mounted) setState(() => loading = false);
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

    final produto = widget.produto;
    if (produto != null) {
      descricao.text = produto.descricao;
      precoCusto.text = produto.precoCusto.toString();
      precoVenda.text = produto.precoVenda.toString();
      estoque.text = produto.estoqueAtual.toString();
      ativo = produto.ativo;
    }
  }

  @override
  void dispose() {
    descricao.dispose();
    precoCusto.dispose();
    precoVenda.dispose();
    estoque.dispose();
    super.dispose();
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
                  label: 'Descricao',
                  controller: descricao,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe a descricao';
                    }
                    return null;
                  },
                ),
                campoTexto(
                  label: 'Preco de custo',
                  controller: precoCusto,
                  tipo: TextInputType.number,
                  validator: validarPrecoCusto,
                ),
                campoTexto(
                  label: 'Preco de venda',
                  controller: precoVenda,
                  tipo: TextInputType.number,
                  validator: validarPrecoVenda,
                ),
                if (widget.produto == null)
                  campoTexto(
                    label: 'Estoque inicial',
                    controller: estoque,
                    tipo: TextInputType.number,
                  ),
                if (widget.produto != null)
                  CheckboxListTile(
                    value: ativo,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Produto ativo'),
                    subtitle: Text(
                      ativo
                          ? 'Disponivel para vendas e buscas'
                          : 'Oculto em vendas e buscas',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) {
                      setState(() {
                        ativo = value ?? true;
                      });
                    },
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
