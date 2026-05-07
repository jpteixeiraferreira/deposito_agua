import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/empresa_context.dart';
import '../models/cliente_model.dart';

class ClienteRepository {
  final supabase = Supabase.instance.client;

  Future<List<Cliente>> buscarTodos({
    bool incluirInativos = false,
    bool somenteInativos = false,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    var query = supabase.from('clientes').select();
    query = query.eq('empresa_id', empresaId);

    if (somenteInativos) {
      query = query.eq('ativo', false);
    } else if (!incluirInativos) {
      query = query.eq('ativo', true);
    }

    final response = await query.order('nome', ascending: true);

    return (response as List).map((item) => Cliente.fromMap(item)).toList();
  }

  Future<void> inserir({
    required String nome,
    required String telefone,
    required String endereco,
    required String referencia,
    required String cpfCnpj,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    await supabase.from('clientes').insert({
      'empresa_id': empresaId,
      'nome': nome,
      'telefone': telefone,
      'endereco': endereco,
      'referencia': referencia,
      'cpf_cnpj': cpfCnpj,
      'ativo': true,
    });
  }

  Future<void> atualizar({
    required String id,
    required String nome,
    required String telefone,
    required String endereco,
    required String referencia,
    required String cpfCnpj,
    required bool ativo,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    await supabase
        .from('clientes')
        .update({
          'nome': nome,
          'telefone': telefone,
          'endereco': endereco,
          'referencia': referencia,
          'cpf_cnpj': cpfCnpj,
          'ativo': ativo,
        })
        .eq('empresa_id', empresaId)
        .eq('id', id);
  }

  Future<bool> excluir(String id) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    try {
      await supabase
          .from('clientes')
          .delete()
          .eq('empresa_id', empresaId)
          .eq('id', id);
      return true;
    } on PostgrestException catch (e) {
      if (e.code == '23503') return false;
      rethrow;
    }
  }

  Future<void> inativar(String id) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    await supabase
        .from('clientes')
        .update({'ativo': false})
        .eq('empresa_id', empresaId)
        .eq('id', id);
  }
}
