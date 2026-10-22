import 'package:flutter/material.dart';

import 'articles_page.dart';
import 'outils.dart';
import 'parametres_page.dart';
import 'profil.dart';

// Le menu qui glisse depuis la gauche quand on touche les trois barres.
class MenuLateral extends StatelessWidget {
  final Profil profil;
  final int ongletActuel;
  final void Function(int) onAller;
  final Future<void> Function() onDonneesEffacees;

  const MenuLateral({
    super.key,
    required this.profil,
    required this.ongletActuel,
    required this.onAller,
    required this.onDonneesEffacees,
  });

  // Une ligne du menu.
  Widget _tuile({
    required IconData icone,
    required String texte,
    required VoidCallback onTap,
    bool actif = false,
  }) {
    return ListTile(
      leading: Icon(icone, color: kPrincipal),
      title: Text(
        texte,
        style: TextStyle(
          fontWeight: actif ? FontWeight.bold : FontWeight.w500,
          color: kPrincipal,
        ),
      ),
      tileColor: actif ? const Color(0x33F7B500) : null,
      onTap: onTap,
    );
  }

  // Ferme le menu puis change d'onglet.
  void _aller(BuildContext context, int index) {
    Navigator.pop(context);
    onAller(index);
  }

  void _bientot(BuildContext context) {
    final messager = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messager.showSnackBar(
      const SnackBar(content: Text('Bientôt disponible')),
    );
  }

  void _articles(BuildContext context) {
    final navigateur = Navigator.of(context);
    navigateur.pop(); // ferme le menu
    navigateur.push(MaterialPageRoute(builder: (_) => const ArticlesPage()));
  }

  void _parametres(BuildContext context) {
    final navigateur = Navigator.of(context);
    navigateur.pop(); // ferme le menu
    navigateur.push(
      MaterialPageRoute(
        builder: (_) => ParametresPage(onDonneesEffacees: onDonneesEffacees),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nom = profil.nom.trim();

    return Drawer(
      child: Column(
        children: [
          // ----- En-tête du menu : croix, avatar, nom, commerce -----
          Container(
            width: double.infinity,
            color: kPrincipal,
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 20),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        tooltip: 'Fermer',
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: kAccent,
                    child: nom.isEmpty
                        ? const Icon(Icons.person, size: 30, color: kPrincipal)
                        : Text(
                            nom[0].toUpperCase(),
                            style: const TextStyle(
                              color: kPrincipal,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nom.isEmpty ? 'Mon espace' : nom,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (profil.commerce.trim().isNotEmpty)
                    Text(
                      profil.commerce.trim(),
                      style: const TextStyle(color: Color(0xFFCFE8D8), fontSize: 12),
                    ),
                ],
              ),
            ),
          ),

          // ----- Les entrées du menu -----
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8),
              children: [
                _tuile(
                  icone: Icons.home_outlined,
                  texte: 'Accueil',
                  actif: ongletActuel == 0,
                  onTap: () => _aller(context, 0),
                ),
                _tuile(
                  icone: Icons.inventory_2_outlined,
                  texte: 'Mes articles',
                  onTap: () => _articles(context),
                ),
                _tuile(
                  icone: Icons.bar_chart,
                  texte: 'Rapports',
                  onTap: () => _bientot(context),
                ),
                _tuile(
                  icone: Icons.groups_outlined,
                  texte: 'Clients',
                  actif: ongletActuel == 3,
                  onTap: () => _aller(context, 3),
                ),
                _tuile(
                  icone: Icons.tune,
                  texte: 'Paramètres',
                  onTap: () => _parametres(context),
                ),
                _tuile(
                  icone: Icons.info_outline,
                  texte: 'À propos',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Sakoche',
                    applicationVersion: '0.8.0',
                    applicationLegalese: 'Le carnet de caisse du petit commerçant.',
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Sakoche · version 0.8.0',
              style: TextStyle(fontSize: 11, color: Color(0xFF5B6B63)),
            ),
          ),
        ],
      ),
    );
  }
}
