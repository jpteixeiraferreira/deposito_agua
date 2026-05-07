import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../permissao_service.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;

  const AppTopBar({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 700;

    return AppBar(
      title: Text(titulo, overflow: TextOverflow.ellipsis),
      actions: mobile ? [_menuMobile(context)] : _acoesDesktop(context),
    );
  }

  List<Widget> _acoesDesktop(BuildContext context) {
    return [
      IconButton(
        tooltip: 'Home',
        icon: const Icon(Icons.home),
        onPressed: () => context.go('/'),
      ),
      IconButton(
        tooltip: 'Produtos',
        icon: const Icon(Icons.inventory),
        onPressed: () => context.go('/produtos'),
      ),
      IconButton(
        tooltip: 'Clientes',
        icon: const Icon(Icons.people),
        onPressed: () => context.go('/clientes'),
      ),
      IconButton(
        tooltip: 'Vendas',
        icon: const Icon(Icons.sell),
        onPressed: () => context.go('/vendas'),
      ),
      IconButton(
        tooltip: 'Relatorios',
        icon: const Icon(Icons.bar_chart),
        onPressed: () => context.go('/relatorios'),
      ),
      FutureBuilder<PerfilPermissao>(
        future: PermissaoService.instance.perfil(),
        builder: (context, snapshot) {
          final perfil = snapshot.data;
          if (perfil == null || !perfil.adminEmpresa) {
            return const SizedBox.shrink();
          }

          return IconButton(
            tooltip: 'Usuarios',
            icon: const Icon(Icons.manage_accounts),
            onPressed: () => context.go('/usuarios'),
          );
        },
      ),
      FutureBuilder<PerfilPermissao>(
        future: PermissaoService.instance.perfil(),
        builder: (context, snapshot) {
          final perfil = snapshot.data;
          if (perfil == null || !perfil.adminGlobal) {
            return const SizedBox.shrink();
          }

          return IconButton(
            tooltip: 'Admin geral',
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => context.go('/admin-geral'),
          );
        },
      ),
      IconButton(
        tooltip: 'Sair',
        icon: const Icon(Icons.logout),
        onPressed: () => Supabase.instance.client.auth.signOut(),
      ),
    ];
  }

  Widget _menuMobile(BuildContext context) {
    return FutureBuilder<PerfilPermissao>(
      future: PermissaoService.instance.perfil(),
      builder: (context, snapshot) {
        final perfil = snapshot.data;

        return PopupMenuButton<String>(
          tooltip: 'Menu',
          onSelected: (value) {
            if (value == 'sair') {
              Supabase.instance.client.auth.signOut();
              return;
            }

            context.go(value);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: '/', child: Text('Home')),
            const PopupMenuItem(value: '/produtos', child: Text('Produtos')),
            const PopupMenuItem(value: '/clientes', child: Text('Clientes')),
            const PopupMenuItem(value: '/vendas', child: Text('Vendas')),
            const PopupMenuItem(value: '/relatorios', child: Text('Relatorios')),
            if (perfil?.adminEmpresa == true)
              const PopupMenuItem(value: '/usuarios', child: Text('Usuarios')),
            if (perfil?.adminGlobal == true)
              const PopupMenuItem(
                value: '/admin-geral',
                child: Text('Admin geral'),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'sair', child: Text('Sair')),
          ],
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const destinos = [
    _Destino(label: 'Home', icon: Icons.home, rota: '/'),
    _Destino(label: 'Produtos', icon: Icons.inventory, rota: '/produtos'),
    _Destino(label: 'Clientes', icon: Icons.people, rota: '/clientes'),
    _Destino(label: 'Vendas', icon: Icons.sell, rota: '/vendas'),
    _Destino(label: 'Relatorios', icon: Icons.bar_chart, rota: '/relatorios'),
  ];

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    if (largura >= 700) return const SizedBox.shrink();

    final local = GoRouterState.of(context).matchedLocation;
    final index = destinos.indexWhere((destino) => destino.rota == local);

    return NavigationBar(
      selectedIndex: index < 0 ? 0 : index,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      onDestinationSelected: (value) => context.go(destinos[value].rota),
      destinations: destinos
          .map(
            (destino) => NavigationDestination(
              icon: Icon(destino.icon),
              label: destino.label,
              tooltip: destino.label,
            ),
          )
          .toList(),
    );
  }
}

class _Destino {
  final String label;
  final IconData icon;
  final String rota;

  const _Destino({
    required this.label,
    required this.icon,
    required this.rota,
  });
}
