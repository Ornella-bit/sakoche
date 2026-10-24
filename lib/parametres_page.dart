import 'package:flutter/material.dart';

import 'base_de_donnees.dart';
import 'sauvegarde.dart';

class ParametresPage extends StatelessWidget {
  // Fonction fournie par la page principale : elle recharge toutes les données à l'écran.
  final Future<void> Function() onDonneesEffacees;

  const ParametresPage({super.key, required this.onDonneesEffacees});

  Future<void> _sauvegarder(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await Sauvegarde.exporter();
    } catch (_) {
      messager.showSnackBar(
        const SnackBar(content: Text('La sauvegarde a échoué. Réessaie.')),
      );
    }
  }

  Future<void> _restaurer(BuildContext context) async {
    final messager = ScaffoldMessenger.of(context);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restaurer une sauvegarde ?'),
          content: const Text(
            'Tes données actuelles seront remplacées par celles du fichier que tu vas choisir. Une copie de sécurité de tes données actuelles est gardée dans le téléphone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Choisir le fichier'),
            ),
          ],
        );
      },
    );
    if (confirme != true) return;

    try {
      final fait = await Sauvegarde.restaurer();
      if (fait == null) return; // l'utilisatrice a annulé
      await onDonneesEffacees(); // recharge tout ce qui est affiché
      messager.showSnackBar(const SnackBar(content: Text('Données restaurées')));
    } on FormatException {
      messager.showSnackBar(
        const SnackBar(content: Text('Ce fichier n’est pas une sauvegarde Sakoche')),
      );
    } catch (_) {
      messager.showSnackBar(
        const SnackBar(content: Text('La restauration a échoué. Réessaie.')),
      );
    }
  }

  Future<void> _effacer(BuildContext context) async {
    // On demande confirmation : effacer est définitif.
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Effacer toutes les données ?'),
          content: const Text(
            'Toutes tes ventes, tes dépenses et les dettes de tes clients seront supprimées. Cette action est définitive. Pense à faire une sauvegarde avant.',
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
            leading: const Icon(Icons.cloud_upload_outlined),
            title: const Text('Sauvegarder mes données'),
            subtitle: const Text('Envoie un fichier à garder (WhatsApp, e-mail...)'),
            onTap: () => _sauvegarder(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download_outlined),
            title: const Text('Restaurer une sauvegarde'),
            subtitle: const Text('Retrouve tes données depuis un fichier'),
            onTap: () => _restaurer(context),
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
