import 'package:flutter/material.dart';

import 'outils.dart';
import 'parametres_page.dart';
import 'profil.dart';
import 'profil_page.dart';

class MoiPage extends StatefulWidget {
  final Future<void> Function() onDonneesEffacees;
  final Future<void> Function() onProfilModifie; // prévient la page principale

  const MoiPage({
    super.key,
    required this.onDonneesEffacees,
    required this.onProfilModifie,
  });

  @override
  State<MoiPage> createState() => _MoiPageState();
}

class _MoiPageState extends State<MoiPage> {
  Profil _profil = const Profil();

  @override
  void initState() {
    super.initState();
    _chargerProfil();
  }

  Future<void> _chargerProfil() async {
    final profil = await Profil.charger();
    if (!mounted) return;
    setState(() {
      _profil = profil;
    });
  }

  Future<void> _ouvrirProfil() async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProfilPage()),
    );
    if (modifie == true) {
      await _chargerProfil();
      await widget.onProfilModifie();
    }
  }

  void _ouvrirParametres() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParametresPage(onDonneesEffacees: widget.onDonneesEffacees),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aUnNom = _profil.nom.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Moi')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: kPrincipal,
              child: aUnNom
                  ? Text(
                      _profil.nom[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.person, size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              aUnNom ? _profil.nom : 'Mon espace',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          if (_profil.commerce.isNotEmpty)
            Center(child: Text(_profil.commerce)),
          if (_profil.telephone.isNotEmpty)
            Center(child: Text(_profil.telephone)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Mon profil'),
            subtitle: const Text('Ton nom, ton commerce, ton téléphone'),
            onTap: _ouvrirProfil,
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Paramètres'),
            onTap: _ouvrirParametres,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('À propos de Sakoche'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Sakoche',
              applicationVersion: '1.0.0',
              applicationLegalese: 'Le carnet de caisse du petit commerçant.',
            ),
          ),
        ],
      ),
    );
  }
}
