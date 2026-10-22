import 'package:flutter/material.dart';

import 'outils.dart';
import 'vente.dart';

class VentesPage extends StatelessWidget {
  final List<Vente> ventes;
  final VoidCallback onNouvelleVente;

  const VentesPage({
    super.key,
    required this.ventes,
    required this.onNouvelleVente,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onNouvelleVente,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle vente'),
      ),
      body: ventes.isEmpty
          ? const Center(child: Text('Aucune vente pour le moment.'))
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: ventes.length,
              itemBuilder: (context, index) => VenteTile(vente: ventes[index]),
            ),
    );
  }
}

// Une vente dans une liste. Un clic dessus ouvre le détail des articles.
class VenteTile extends StatelessWidget {
  final Vente vente;

  const VenteTile({super.key, required this.vente});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.shopping_bag_outlined, color: kIndigo),
      title: Text(
        '${formaterMontant(vente.montant)} FCFA',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${vente.resume}\n${formaterDateHeure(vente.date)}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      onTap: () => _afficherDetail(context),
    );
  }

  void _afficherDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Détail de la vente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(formaterDateHeure(vente.date)),
              const SizedBox(height: 16),
              if (vente.lignes.isEmpty)
                const Text('Cette vente a été enregistrée sans détail des articles.'),
              for (final ligne in vente.lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text('${ligne.quantite} × ${ligne.article}')),
                      Text('${formaterMontant(ligne.montant)} FCFA'),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${formaterMontant(vente.montant)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
