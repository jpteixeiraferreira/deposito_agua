import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente_model.dart';

class ClienteRepository {
  final supabase = Supabase.instance.client;

  Future<List<Cliente>> buscarTodos() async {
    final response = await supabase
        .from('clientes')
        .select()
        .order('nome', ascending: true);

    return (response as List).map((item) => Cliente.fromMap(item)).toList();
  }

  Future<void> inserir({
    required String nome,
    required String telefone,
    required String endereco,
    required String referencia,
    required String cpfCnpj,
  }) async {
    await supabase.from('clientes').insert({
      'nome': nome,
      'telefone': telefone,
      'endereco': endereco,
      'referencia': referencia,
      'cpf_cnpj': cpfCnpj,
    });
  }

  Future<void> atualizar({
    required String id,
    required String nome,
    required String telefone,
    required String endereco,
    required String referencia,
    required String cpfCnpj,
  }) async {
    await supabase
        .from('clientes')
        .update({
          'nome': nome,
          'telefone': telefone,
          'endereco': endereco,
          'referencia': referencia,
          'cpf_cnpj': cpfCnpj,
        })
        .eq('id', id);
  }
}
