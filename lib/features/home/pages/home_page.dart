import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget cardMenu({
    required BuildContext context,
    required IconData icon,
    required String titulo,
    required String rota,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go(rota),
      child: Card(
        elevation: 3,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(title: const Text('Depósito de Água'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: desktop ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            cardMenu(
              context: context,
              icon: Icons.inventory,
              titulo: 'Produtos',
              rota: '/produtos',
            ),
            cardMenu(
              context: context,
              icon: Icons.people,
              titulo: 'Clientes',
              rota: '/clientes',
            ),
            cardMenu(
              context: context,
              icon: Icons.point_of_sale,
              titulo: 'Vendas',
              rota: '/vendas',
            ),
            cardMenu(
              context: context,
              icon: Icons.bar_chart,
              titulo: 'Relatórios',
              rota: '/relatorios',
            ),
          ],
        ),
      ),
    );
  }
}
