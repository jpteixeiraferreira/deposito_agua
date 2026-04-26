import 'package:go_router/go_router.dart';
import '../features/home/pages/home_page.dart';
import '../features/clientes/pages/clientes_page.dart';
import '../features/produtos/pages/produtos_page.dart';
import '../features/vendas/pages/vendas_page.dart';
import '../features/relatorios/pages/relatorios_page.dart';

final router = GoRouter(
  routes: [
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
  ],
);
