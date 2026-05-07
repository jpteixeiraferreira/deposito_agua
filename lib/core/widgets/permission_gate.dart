import 'package:flutter/material.dart';

import '../permissao_service.dart';

class PermissionGate extends StatelessWidget {
  final bool Function(PerfilPermissao perfil) permitir;
  final Widget child;
  final String mensagem;

  const PermissionGate({
    super.key,
    required this.permitir,
    required this.child,
    this.mensagem = 'Voce nao tem permissao para acessar esta area.',
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PerfilPermissao>(
      future: PermissaoService.instance.perfil(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!permitir(snapshot.data!)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Acesso restrito')),
            body: Center(child: Text(mensagem)),
          );
        }

        return child;
      },
    );
  }
}
