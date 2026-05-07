import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/empresa_context.dart';
import '../models/config_recibo_model.dart';

class ConfigReciboRepository {
  final supabase = Supabase.instance.client;

  Future<ConfigRecibo> buscar() async {
    try {
      final empresaId = await EmpresaContext.instance.empresaId();
      final response = await supabase
          .from('configuracoes_recibo')
          .select()
          .eq('empresa_id', empresaId)
          .maybeSingle();

      if (response == null) {
        return ConfigRecibo.padrao();
      }

      return ConfigRecibo.fromMap(response);
    } catch (_) {
      return ConfigRecibo.padrao();
    }
  }

  Future<void> salvar(ConfigRecibo config) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final map = config.toMap()..remove('id');
    map['empresa_id'] = empresaId;

    await supabase
        .from('configuracoes_recibo')
        .upsert(map, onConflict: 'empresa_id');
  }

  Future<String> enviarLogo({
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    final empresaId = await EmpresaContext.instance.empresaId();
    final extensao = nomeArquivo.split('.').last.toLowerCase();
    final path =
        '$empresaId/logo-${DateTime.now().millisecondsSinceEpoch}.$extensao';

    await supabase.storage.from('recibos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('recibos').getPublicUrl(path);
  }
}
