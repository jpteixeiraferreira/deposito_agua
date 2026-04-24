import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;

  const AppTopBar({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titulo),
      actions: [
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
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
