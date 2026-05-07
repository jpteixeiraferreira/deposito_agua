import 'package:supabase_flutter/supabase_flutter.dart';

import 'empresa_context.dart';

class PerfilPermissao {
  final bool adminGlobal;
  final String? papelEmpresa;

  const PerfilPermissao({
    required this.adminGlobal,
    required this.papelEmpresa,
  });

  bool get adminEmpresa => papelEmpresa == 'admin';
  bool get gerente => papelEmpresa == 'gerente';
  bool get podeGerenciarUsuarios => adminGlobal || adminEmpresa;
  bool get podeAdministrarEmpresa => adminGlobal || adminEmpresa;
  bool get podeVerRelatorios =>
      adminGlobal || adminEmpresa || gerente || papelEmpresa == 'consulta';
  bool get podeVender =>
      adminGlobal ||
      adminEmpresa ||
      gerente ||
      papelEmpresa == 'operador';
}

class PermissaoService {
  PermissaoService._();

  static final instance = PermissaoService._();

  final _supabase = Supabase.instance.client;
  PerfilPermissao? _cache;

  void limparCache() {
    _cache = null;
  }

  Future<PerfilPermissao> perfil() async {
    if (_cache != null) return _cache!;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const PerfilPermissao(adminGlobal: false, papelEmpresa: null);
    }

    final adminGlobalResponse = await _supabase
        .from('admins_globais')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();

    String? papel;
    try {
      final empresaId = await EmpresaContext.instance.empresaId();
      final vinculo = await _supabase
          .from('usuarios_empresas')
          .select('papel')
          .eq('empresa_id', empresaId)
          .eq('user_id', user.id)
          .eq('ativo', true)
          .maybeSingle();
      papel = vinculo?['papel']?.toString();
    } catch (_) {
      papel = null;
    }

    _cache = PerfilPermissao(
      adminGlobal: adminGlobalResponse != null,
      papelEmpresa: papel,
    );
    return _cache!;
  }
}
