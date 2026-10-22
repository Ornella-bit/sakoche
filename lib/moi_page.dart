import 'package:flutter/material.dart';

import 'outils.dart';

class MoiPage extends StatelessWidget {
  const MoiPage({super.key});

  void _bientot(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bientôt disponible')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moi')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: kIndigo,
              child: Icon(Icons.person, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Mon espace',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Mon profil'),
            subtitle: const Text('Ton nom, ton commerce, ton téléphone'),
            onTap: () => _bientot(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Paramètres'),
            onTap: () => _bientot(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos de Sakoche'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Sakoche',
              applicationVersion: '0.5.0',
              applicationLegalese: 'Le carnet de caisse du petit commerçant.',
            ),
          ),
        ],
      ),
    );
  }
}
