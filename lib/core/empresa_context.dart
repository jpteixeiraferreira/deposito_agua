import 'package:supabase_flutter/supabase_flutter.dart';

class EmpresaContext {
  EmpresaContext._();

  static final instance = EmpresaContext._();

  final _supabase = Supabase.instance.client;
  String? _empresaId;

  void limparCache() {
    _empresaId = null;
  }

  Future<String> empresaId() async {
    if (_empresaId != null) return _empresaId!;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado');
    }

    final response = await _supabase
        .from('usuarios_empresas')
        .select('empresa_id')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();

    final empresaId = response?['empresa_id']?.toString();
    if (empresaId == null || empresaId.isEmpty) {
      throw Exception('Usuario sem empresa vinculada');
    }

    _empresaId = empresaId;
    return empresaId;
  }
}
