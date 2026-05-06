import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/config_recibo_model.dart';

class ConfigReciboRepository {
  final supabase = Supabase.instance.client;

  Future<ConfigRecibo> buscar() async {
    try {
      final response = await supabase
          .from('configuracoes_recibo')
          .select()
          .eq('id', 1)
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
    await supabase
        .from('configuracoes_recibo')
        .upsert(config.toMap(), onConflict: 'id');
  }

  Future<String> enviarLogo({
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    final extensao = nomeArquivo.split('.').last.toLowerCase();
    final path =
        'logo-${DateTime.now().millisecondsSinceEpoch}.$extensao';

    await supabase.storage.from('recibos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return supabase.storage.from('recibos').getPublicUrl(path);
  }
}
