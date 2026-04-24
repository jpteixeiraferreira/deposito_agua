import 'package:go_router/go_router.dart';
import '../features/produtos/pages/produtos_page.dart';

final router = GoRouter(
  routes: [GoRoute(path: '/', builder: (context, state) => ProdutosPage())],
);
