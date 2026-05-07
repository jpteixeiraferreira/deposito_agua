import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'empresa_context.dart';
import 'permissao_service.dart';
import '../features/auth/pages/login_page.dart';
import '../features/admin/pages/admin_geral_page.dart';
import '../features/admin/pages/usuarios_empresa_page.dart';
import 'widgets/permission_gate.dart';
import '../features/clientes/pages/clientes_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/produtos/pages/produtos_page.dart';
import '../features/relatorios/pages/relatorios_page.dart';
import '../features/vendas/pages/vendas_page.dart';

final authNotifier = AuthStateNotifier();

final router = GoRouter(
  refreshListenable: authNotifier,
  redirect: (context, state) {
    final logado = Supabase.instance.client.auth.currentSession != null;
    final indoParaLogin = state.matchedLocation == '/login';

    if (!logado && !indoParaLogin) return '/login';
    if (logado && indoParaLogin) return '/';

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/clientes',
      builder: (context, state) => const ClientesPage(),
    ),
    GoRoute(
      path: '/produtos',
      builder: (context, state) => const ProdutosPage(),
    ),
    GoRoute(path: '/vendas', builder: (context, state) => const VendasPage()),
    GoRoute(
      path: '/relatorios',
      builder: (context, state) => const RelatoriosPage(),
    ),
    GoRoute(
      path: '/usuarios',
      builder: (context, state) => PermissionGate(
        permitir: (perfil) => perfil.adminEmpresa,
        child: const UsuariosEmpresaPage(),
      ),
    ),
    GoRoute(
      path: '/admin-geral',
      builder: (context, state) => PermissionGate(
        permitir: (perfil) => perfil.adminGlobal,
        child: const AdminGeralPage(),
      ),
    ),
  ],
);

class AuthStateNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _subscription;

  void start() {
    if (_subscription != null) return;
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      EmpresaContext.instance.limparCache();
      PermissaoService.instance.limparCache();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
