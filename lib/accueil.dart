import 'package:flutter/material.dart';

import 'outils.dart';
import 'vente.dart';
import 'ventes_page.dart';

class AccueilPage extends StatelessWidget {
  final List<Vente> ventes;
  final VoidCallback onNouvelleVente;

  const AccueilPage({
    super.key,
    required this.ventes,
    required this.onNouvelleVente,
  });

  @override
  Widget build(BuildContext context) {
    // On ne garde que les ventes d'aujourd'hui pour le résumé du haut.
    final maintenant = DateTime.now();
    final duJour = ventes.where((v) => memeJour(v.date, maintenant)).toList();
    int total = 0;
    for (final vente in duJour) {
      total += vente.montant;
    }
    final recentes = ventes.take(5).toList();
    final nombre = duJour.length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: kIndigo,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sakoche',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ventes du jour',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formaterMontant(total)} FCFA',
                  style: const TextStyle(
                    color: kOcre,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre <= 1
                      ? '$nombre vente aujourd’hui'
                      : '$nombre ventes aujourd’hui',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: onNouvelleVente,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle vente'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Dernières ventes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(
          child: recentes.isEmpty
              ? const Center(child: Text('Aucune vente pour le moment.'))
              : ListView(
                  children: [
                    for (final vente in recentes) VenteTile(vente: vente),
                  ],
                ),
        ),
      ],
    );
  }
}
