import 'package:flutter/material.dart';

import 'accueil_page.dart';
import 'base_de_donnees.dart';
import 'client.dart';
import 'clients_page.dart';
import 'depense.dart';
import 'depenses_page.dart';
import 'menu_lateral.dart';
import 'moi_page.dart';
import 'nouvelle_vente_page.dart';
import 'outils.dart';
import 'profil.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: kPrincipal),
        scaffoldBackgroundColor: kFond,
        navigationBarTheme: const NavigationBarThemeData(
          indicatorColor: Color(0x59F7B500),
          // Taille de police FIXE pour les noms des onglets.
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        useMaterial3: true,
      ),
      home: const Coque(),
    );
  }
}

// La "coque" : le menu latéral, la barre d'onglets en bas
// et la page de l'onglet choisi.
class Coque extends StatefulWidget {
  const Coque({super.key});

  @override
  State<Coque> createState() => _CoqueState();
}

class _CoqueState extends State<Coque> {
  int _onglet = 0;
  List<Vente> _ventes = [];
  List<Depense> _depenses = [];
  List<Client> _clients = [];
  List<OperationClient> _operations = [];
  Profil _profil = const Profil();

  @override
  void initState() {
    super.initState();
    _chargerVentes();
    _chargerDepenses();
    _chargerClients();
    _chargerProfil();
  }

  Future<void> _chargerVentes() async {
    final ventes = await BaseDeDonnees.lireVentes();
    if (!mounted) return;
    setState(() {
      _ventes = ventes;
    });
  }

  Future<void> _chargerDepenses() async {
    final depenses = await BaseDeDonnees.lireDepenses();
    if (!mounted) return;
    setState(() {
      _depenses = depenses;
    });
  }

  // Les clients (avec leurs dettes) et toutes les opérations de dettes.
  Future<void> _chargerClients() async {
    final clients = await BaseDeDonnees.lireClients();
    final operations = await BaseDeDonnees.lireToutesOperations();
    if (!mounted) return;
    setState(() {
      _clients = clients;
      _operations = operations;
    });
  }

  // Après "Effacer toutes mes données" : on recharge tout.
  Future<void> _rechargerTout() async {
    await _chargerVentes();
    await _chargerDepenses();
    await _chargerClients();
  }

  Future<void> _chargerProfil() async {
    final profil = await Profil.charger();
    if (!mounted) return;
    setState(() {
      _profil = profil;
    });
  }

  void _aller(int index) {
    setState(() {
      _onglet = index;
    });
  }

  Future<void> _nouvelleVente() async {
    final enregistree = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NouvelleVentePage()),
    );
    if (enregistree == true) {
      await _chargerVentes();
      await _chargerClients(); // une vente à crédit change les dettes
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      AccueilPage(
        ventes: _ventes,
        depenses: _depenses,
        operations: _operations,
        profil: _profil,
        onNouvelleVente: _nouvelleVente,
        onOuvrirMoi: () => _aller(4),
      ),
      VentesPage(ventes: _ventes, onNouvelleVente: _nouvelleVente),
      DepensesPage(depenses: _depenses, onChange: _chargerDepenses),
      ClientsPage(clients: _clients, onChange: _chargerClients),
      MoiPage(
        onDonneesEffacees: _rechargerTout,
        onProfilModifie: _chargerProfil,
      ),
    ];

    // PopScope décide ce que fait le bouton "retour" du téléphone :
    // - sur l'accueil (onglet 0) : on laisse l'application se fermer ;
    // - sur un autre onglet : on revient à l'accueil.
    return PopScope(
      canPop: _onglet == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _aller(0);
        }
      },
      child: Scaffold(
      drawer: MenuLateral(
        profil: _profil,
        ongletActuel: _onglet,
        onAller: _aller,
        onDonneesEffacees: _rechargerTout,
      ),
      body: IndexedStack(index: _onglet, children: pages),
      // On empêche la taille du texte du téléphone d'agrandir la barre du bas.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.0,
        child: NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: _aller,
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
      ),
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
              Icon(icone, size: 56, color: kPrincipal),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
