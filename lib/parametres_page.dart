import 'package:flutter/material.dart';

import 'base_de_donnees.dart';

class ParametresPage extends StatelessWidget {
  // Fonction fournie par la page principale : elle recharge les ventes à l'écran.
  final Future<void> Function() onDonneesEffacees;

  const ParametresPage({super.key, required this.onDonneesEffacees});

  Future<void> _effacer(BuildContext context) async {
    // On demande confirmation : effacer est définitif.
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Effacer toutes les données ?'),
          content: const Text(
            'Toutes tes ventes, tes dépenses et les dettes de tes clients seront supprimées. Cette action est définitive.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Effacer'),
            ),
          ],
        );
      },
    );

    if (confirme != true) return;

    await BaseDeDonnees.toutEffacer();
    await onDonneesEffacees();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Données effacées')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.payments_outlined),
            title: Text('Devise'),
            subtitle: Text('Franc CFA (FCFA)'),
          ),
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('Langue'),
            subtitle: Text('Français'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Effacer toutes mes données',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Supprime ventes, dépenses et dettes enregistrées'),
            onTap: () => _effacer(context),
          ),
        ],
      ),
    );
  }
}
