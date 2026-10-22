import 'package:flutter/material.dart';

import 'accueil_page.dart';
import 'base_de_donnees.dart';
import 'moi_page.dart';
import 'nouvelle_vente_page.dart';
import 'outils.dart';
import 'vente.dart';
import 'ventes_page.dart';

void main() {
  runApp(const SakocheApp());
}

class SakocheApp extends StatelessWidget {
  const SakocheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sakoche',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kIndigo),
        scaffoldBackgroundColor: kFond,
        navigationBarTheme: const NavigationBarThemeData(
          indicatorColor: Color(0x59E0A526),
        ),
        useMaterial3: true,
      ),
      home: const Coque(),
    );
  }
}

// La "coque" : l'écran qui contient la barre d'onglets en bas
// et qui affiche la page de l'onglet choisi.
class Coque extends StatefulWidget {
  const Coque({super.key});

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> {
  int _onglet = 0;
  List<Vente> _ventes = [];

  @override
  void initState() {
    super.initState();
    _chargerVentes();
  }

  Future<void> _chargerVentes() async {
    final ventes = await BaseDeDonnees.lireVentes();
    if (!mounted) return;
    setState(() {
      _ventes = ventes;
    });
  }

  // Ouvre la page "Nouvelle vente" et, au retour, recharge la liste.
  Future<void> _nouvelleVente() async {
    final enregistree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NouvelleVentePage()),
    );
    if (enregistree == true) {
      await _chargerVentes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      AccueilPage(ventes: _ventes, onNouvelleVente: _nouvelleVente),
      VentesPage(ventes: _ventes, onNouvelleVente: _nouvelleVente),
      const BientotPage(
        titre: 'Dépenses',
        icone: Icons.receipt_long_outlined,
        message: 'Bientôt : note ce que tu dépenses pour ton commerce.',
      ),
      const BientotPage(
        titre: 'Clients',
        icone: Icons.groups_outlined,
        message: 'Bientôt : suis les dettes de tes clients et leurs remboursements.',
      ),
      const MoiPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _onglet, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _onglet,
        onDestinationSelected: (index) {
          setState(() {
            _onglet = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Ventes',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Dépenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Clients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Moi',
          ),
        ],
      ),
    );
  }
}

// Page provisoire pour les onglets pas encore construits.
class BientotPage extends StatelessWidget {
  final String titre;
  final IconData icone;
  final String message;

  const BientotPage({
    super.key,
    required this.titre,
    required this.icone,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 56, color: kIndigo),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}