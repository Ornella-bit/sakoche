import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  // Le montant de la vente : c'est tout ce qu'il faut pour enregistrer une vente.
  final TextEditingController _montantController = TextEditingController();

  // Les champs du détail des articles (facultatif).
  final TextEditingController _articleController = TextEditingController();
  final TextEditingController _quantiteController = TextEditingController(text: '1');
  final TextEditingController _prixController = TextEditingController();
  final TextEditingController _payeController = TextEditingController(text: '0');
  final FocusNode _articleFocus = FocusNode();

  final List<LigneVente> _lignes = []; // vide si le commerçant ne détaille pas
  List<Article> _articles = []; // le catalogue ("Mes articles")
  List<Client> _clients = [];
  bool _credit = false;
  Client? _clientChoisi;

  // Le total : la somme des articles s'il y en a, sinon le montant tapé.
  int get _total {
    if (_lignes.isNotEmpty) {
      int somme = 0;
      for (final ligne in _lignes) {
        somme += ligne.montant;
      }
      return somme;
    }
    return int.tryParse(_montantController.text.trim()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _chargerArticles();
    _chargerClients();
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

  // Quand des articles sont détaillés, le champ du montant affiche leur total.
  // Quand il n'y en a plus, on le vide pour que le commerçant retape son montant.
  void _actualiserMontant() {
    if (_lignes.isEmpty) {
      _montantController.clear();
    } else {
      _montantController.text = _total.toString();
    }
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
      _actualiserMontant();
    });
  }

  void _ajouterLigne() {
    final article = _articleController.text.trim();
    final quantite = int.tryParse(_quantiteController.text.trim());
    final prix = int.tryParse(_prixController.text.trim());

    if (article.isEmpty) {
      _message('Écris le nom de l’article vendu');
      return;
    }
    if (quantite == null || quantite <= 0) {
      _message('La quantité doit être au moins 1');
      return;
    }
    if (prix == null || prix <= 0) {
      _message('Entre le prix d’une unité, par exemple 500');
      return;
    }

    setState(() {
      _ajouterOuFusionner(
        LigneVente(article: article, quantite: quantite, prixUnitaire: prix),
      );
      _actualiserMontant();
    });

    // On prépare les champs pour l'article suivant.
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
    final total = _total;
    if (total <= 0) {
      _message('Entre le montant de la vente');
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
      lignes: List.of(_lignes), // peut être vide : le détail est facultatif
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

  @override
  Widget build(BuildContext context) {
    final paye = int.tryParse(_payeController.text.trim()) ?? 0;
    final reste = _total - paye < 0 ? 0 : _total - paye;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ----- L'essentiel : le montant. Le clavier s'ouvre tout de suite. -----
          TextField(
            controller: _montantController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            readOnly: _lignes.isNotEmpty, // calculé quand des articles sont détaillés
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Montant de la vente (FCFA)',
              helperText: _lignes.isNotEmpty ? 'Calculé d’après les articles' : null,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),

          // ----- Le détail des articles : facultatif, replié par défaut -----
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: const Text(
              'Détailler les articles (facultatif)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: _lignes.isEmpty
                ? null
                : Text(_lignes.length == 1 ? '1 article' : '${_lignes.length} articles'),
            children: [
              if (_articles.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mes articles', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Touche un article pour l’ajouter, touche-le encore pour augmenter la quantité.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5B6B63)),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
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
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _articleController,
                focusNode: _articleFocus,
                textCapitalization: TextCapitalization.sentences,
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
                      decoration: const InputDecoration(
                        labelText: 'Prix unitaire (FCFA)',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _ajouterLigne(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _ajouterLigne,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Ajouter cet article'),
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
                            _actualiserMontant();
                          });
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // ----- La vente à crédit -----
          const Divider(height: 24),
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
