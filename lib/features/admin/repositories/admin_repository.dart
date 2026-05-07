import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/empresa_context.dart';

class AdminRepository {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> buscarEmpresas() async {
    final response = await supabase
        .from('empresas')
        .select('id, nome, ativo, criado_em')
        .order('nome');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> buscarUsuariosEmpresa({
    String? empresaId,
  }) async {
    final id = empresaId ?? await EmpresaContext.instance.empresaId();

    final response = await supabase
        .from('usuarios_empresas')
        .select('user_id, empresa_id, nome, email, papel, ativo, criado_em')
        .eq('empresa_id', id)
        .order('nome');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> criarEmpresaComAdmin({
    required String nomeEmpresa,
    required String nomeUsuario,
    required String email,
    required String senha,
  }) async {
    final response = await supabase.functions.invoke(
      'admin',
      body: {
        'acao': 'criar_empresa_com_admin',
        'nome_empresa': nomeEmpresa,
        'nome_usuario': nomeUsuario,
        'email': email,
        'senha': senha,
      },
    );
    _verificarErro(response);
  }

  Future<void> criarUsuarioEmpresa({
    required String nome,
    required String email,
    required String senha,
    required String papel,
    String? empresaId,
  }) async {
    final response = await supabase.functions.invoke(
      'admin',
      body: {
        'acao': 'criar_usuario_empresa',
        'empresa_id': empresaId ?? await EmpresaContext.instance.empresaId(),
        'nome': nome,
        'email': email,
        'senha': senha,
        'papel': papel,
      },
    );
    _verificarErro(response);
  }

  Future<void> atualizarUsuarioEmpresa({
    required String userId,
    required String empresaId,
    required String papel,
    required bool ativo,
  }) async {
    final response = await supabase.functions.invoke(
      'admin',
      body: {
        'acao': 'atualizar_usuario_empresa',
        'empresa_id': empresaId,
        'user_id': userId,
        'papel': papel,
        'ativo': ativo,
      },
    );
    _verificarErro(response);
  }

  void _verificarErro(FunctionResponse response) {
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}
