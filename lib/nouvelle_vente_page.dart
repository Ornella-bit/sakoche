import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'article.dart';
import 'base_de_donnees.dart';
import 'client.dart';
import 'clients_page.dart';
import 'outils.dart';
import 'vente.dart';

class NouvelleVentePage extends StatefulWidget {
  const NouvelleVentePage({super.key});

  @override
  State<NouvelleVentePage> createState() => _NouvelleVentePageState();
}

class _NouvelleVentePageState extends State<NouvelleVentePage> {
  // Mode "Montant" : un seul champ.
  final TextEditingController _montantController = TextEditingController();

  // Mode "Articles" : les champs pour un article.
  final TextEditingController _articleController = TextEditingController();
  final TextEditingController _quantiteController = TextEditingController(text: '1');
  final TextEditingController _prixController = TextEditingController();
  final FocusNode _articleFocus = FocusNode();

  // Vente à crédit.
  final TextEditingController _payeController = TextEditingController(text: '0');

  bool _parArticles = false; // false = "Montant", true = "Articles"
  bool _modeCharge = false; // vrai quand on a retrouvé le dernier mode utilisé

  final List<LigneVente> _lignes = []; // les articles déjà ajoutés à la vente
  List<Article> _articles = []; // le catalogue ("Mes articles")
  List<Client> _clients = [];
  bool _credit = false;
  Client? _clientChoisi;

  // L'article en cours de saisie (pas encore ajouté), s'il est complet.
  // Il compte déjà dans le total : pas besoin d'appuyer sur "Ajouter" avant d'enregistrer.
  LigneVente? get _ligneEnCours {
    final article = _articleController.text.trim();
    final quantite = int.tryParse(_quantiteController.text.trim());
    final prix = int.tryParse(_prixController.text.trim());
    if (article.isEmpty || quantite == null || quantite <= 0 || prix == null || prix <= 0) {
      return null;
    }
    return LigneVente(article: article, quantite: quantite, prixUnitaire: prix);
  }

  // Le total : en mode "Montant", le montant tapé ; en mode "Articles",
  // la somme des articles ajoutés plus l'article en cours de saisie.
  int get _total {
    if (!_parArticles) {
      return int.tryParse(_montantController.text.trim()) ?? 0;
    }
    int somme = 0;
    for (final ligne in _lignes) {
      somme += ligne.montant;
    }
    final enCours = _ligneEnCours;
    if (enCours != null) {
      somme += enCours.montant;
    }
    return somme;
  }

  @override
  void initState() {
    super.initState();
    _chargerMode();
    _chargerArticles();
    _chargerClients();
  }

  // On retrouve le dernier mode utilisé : celui qui détaille toujours ses articles
  // n'aura pas à changer de mode à chaque vente.
  Future<void> _chargerMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _parArticles = prefs.getBool('vente_par_articles') ?? false;
      _modeCharge = true;
    });
  }

  Future<void> _changerMode(bool parArticles) async {
    setState(() {
      _parArticles = parArticles;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vente_par_articles', parArticles);
  }

  Future<void> _chargerArticles() async {
    final articles = await BaseDeDonnees.lireArticles();
    if (!mounted) return;
    setState(() {
      _articles = articles;
    });
  }

  Future<void> _chargerClients() async {
    final clients = await BaseDeDonnees.lireClients();
    if (!mounted) return;
    setState(() {
      _clients = clients;
    });
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // Ajoute une ligne. Si le même article au même prix est déjà là,
  // on augmente simplement sa quantité.
  void _ajouterOuFusionner(LigneVente nouvelle) {
    final index = _lignes.indexWhere(
      (l) =>
          l.article.toLowerCase() == nouvelle.article.toLowerCase() &&
          l.prixUnitaire == nouvelle.prixUnitaire,
    );
    if (index >= 0) {
      final ancienne = _lignes[index];
      _lignes[index] = LigneVente(
        article: ancienne.article,
        quantite: ancienne.quantite + nouvelle.quantite,
        prixUnitaire: ancienne.prixUnitaire,
      );
    } else {
      _lignes.add(nouvelle);
    }
  }

  // Un clic sur un article du catalogue l'ajoute directement (quantité 1).
  void _ajouterRapide(Article article) {
    setState(() {
      _ajouterOuFusionner(
        LigneVente(article: article.nom, quantite: 1, prixUnitaire: article.prix),
      );
    });
  }

  // Quand le nom tapé correspond à un article du catalogue, on remplit son prix.
  void _nomModifie(String texte) {
    final nom = texte.trim().toLowerCase();
    if (_prixController.text.isEmpty) {
      for (final article in _articles) {
        if (article.nom.toLowerCase() == nom) {
          _prixController.text = article.prix.toString();
          break;
        }
      }
    }
    setState(() {});
  }

  // Le bouton "Ajouter cet article" : valide l'article en cours et prépare le suivant.
  void _ajouterLigne() {
    final enCours = _ligneEnCours;
    if (enCours == null) {
      if (_articleController.text.trim().isEmpty) {
        _message('Écris le nom de l’article vendu');
      } else if ((int.tryParse(_quantiteController.text.trim()) ?? 0) <= 0) {
        _message('La quantité doit être au moins 1');
      } else {
        _message('Entre le prix d’une unité, par exemple 500');
      }
      return;
    }

    setState(() {
      _ajouterOuFusionner(enCours);
    });

    _articleController.clear();
    _quantiteController.text = '1';
    _prixController.clear();
    _articleFocus.requestFocus();
  }

  // Une feuille qui propose la liste des clients, avec "Nouveau client" en premier.
  Future<void> _choisirClient() async {
    final choix = await showModalBottomSheet<Client>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: const Text('Nouveau client'),
                onTap: () async {
                  final nouveau = await demanderNouveauClient(sheetContext);
                  if (nouveau != null && sheetContext.mounted) {
                    Navigator.pop(sheetContext, nouveau);
                  }
                },
              ),
              for (final client in _clients)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(client.nom),
                  subtitle: client.dette > 0
                      ? Text('Doit déjà ${formaterMontant(client.dette)} FCFA')
                      : null,
                  onTap: () => Navigator.pop(sheetContext, client),
                ),
            ],
          ),
        );
      },
    );
    if (choix == null) return;
    await _chargerClients();
    if (!mounted) return;
    setState(() {
      _clientChoisi = choix;
    });
  }

  Future<void> _enregistrer() async {
    // En mode "Articles" : un article commencé mais incomplet ne doit pas être oublié en silence.
    if (_parArticles) {
      final saisieIncomplete =
          _articleController.text.trim().isNotEmpty && _ligneEnCours == null;
      if (saisieIncomplete) {
        _message('Il manque le prix ou la quantité de l’article en cours');
        return;
      }
      // L'article en cours, s'il est complet, est ajouté automatiquement.
      final enCours = _ligneEnCours;
      if (enCours != null) {
        _ajouterOuFusionner(enCours);
      }
    }

    final total = _total;
    if (total <= 0) {
      _message(_parArticles ? 'Ajoute au moins un article avec son prix' : 'Entre le montant de la vente');
      return;
    }

    // Si la vente est à crédit : ce qui n'est pas payé tout de suite
    // devient une dette du client.
    int credit = 0;
    int? clientId;
    if (_credit) {
      if (_clientChoisi == null) {
        _message('Choisis le client qui prend à crédit');
        return;
      }
      final paye = int.tryParse(_payeController.text.trim()) ?? 0;
      if (paye > total) {
        _message('Le montant payé dépasse le total de la vente');
        return;
      }
      credit = total - paye;
      clientId = _clientChoisi!.id;
    }

    final vente = Vente(
      date: DateTime.now(),
      lignes: _parArticles ? List.of(_lignes) : <LigneVente>[],
      montant: total,
      clientId: clientId,
      credit: credit,
    );
    await BaseDeDonnees.ajouterVente(vente);
    if (!mounted) return;

    // On revient à la page précédente en disant "c'est enregistré" (true).
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _montantController.dispose();
    _articleController.dispose();
    _quantiteController.dispose();
    _prixController.dispose();
    _payeController.dispose();
    _articleFocus.dispose();
    super.dispose();
  }

  // ----- Le mode "Montant" : un seul champ -----
  Widget _blocMontant() {
    return TextField(
      controller: _montantController,
      autofocus: true, // le clavier s'ouvre tout de suite
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        labelText: 'Montant de la vente (FCFA)',
        border: OutlineInputBorder(),
      ),
    );
  }

  // ----- Le mode "Articles" : choisir ou taper les articles, le total se calcule seul -----
  Widget _blocArticles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_articles.isNotEmpty) ...[
          const Text('Mes articles', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Touche un article pour l’ajouter, touche-le encore pour augmenter la quantité.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5B6B63)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _articles)
                ActionChip(
                  label: Text('${a.nom} · ${formaterMontant(a.prix)}'),
                  onPressed: () => _ajouterRapide(a),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Autre article', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _articleController,
          focusNode: _articleFocus,
          textCapitalization: TextCapitalization.sentences,
          onChanged: _nomModifie,
          decoration: const InputDecoration(
            labelText: 'Article vendu',
            hintText: 'Ex : sac de riz, sachet d’eau',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _quantiteController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _prixController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _ajouterLigne(),
                decoration: const InputDecoration(
                  labelText: 'Prix unitaire (FCFA)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _ajouterLigne,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Ajouter un autre article'),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _lignes.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${_lignes[i].quantite} × ${_lignes[i].article}'),
            subtitle: Text('${formaterMontant(_lignes[i].prixUnitaire)} FCFA l’unité'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${formaterMontant(_lignes[i].montant)} FCFA',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _lignes.removeAt(i);
                    });
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final paye = int.tryParse(_payeController.text.trim()) ?? 0;
    final reste = _total - paye < 0 ? 0 : _total - paye;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: !_modeCharge
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Un choix clair : je note juste le montant, ou je détaille les articles.
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.payments_outlined),
                      label: Text('Montant'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.shopping_basket_outlined),
                      label: Text('Articles'),
                    ),
                  ],
                  selected: {_parArticles},
                  onSelectionChanged: (choix) => _changerMode(choix.first),
                ),
                const SizedBox(height: 16),
                if (_parArticles) _blocArticles() else _blocMontant(),

                // ----- La vente à crédit -----
                const Divider(height: 32),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vente à crédit'),
                  subtitle: const Text('Le client paie plus tard (tout ou une partie)'),
                  value: _credit,
                  onChanged: (valeur) {
                    setState(() {
                      _credit = valeur;
                    });
                  },
                ),
                if (_credit) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _choisirClient,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.person_outline),
                    label: Text(_clientChoisi?.nom ?? 'Choisir un client'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _payeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Montant payé tout de suite (FCFA)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reste à payer : ${formaterMontant(reste)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFB3261E)),
                  ),
                ],
              ],
            ),

      // ----- Barre du bas : le total et le bouton pour enregistrer -----
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 16)),
                  Text(
                    '${formaterMontant(_total)} FCFA',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kPrincipal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _enregistrer,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Enregistrer la vente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
