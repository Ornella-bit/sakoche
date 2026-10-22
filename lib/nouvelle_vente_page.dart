import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_de_donnees.dart';
import 'outils.dart';
import 'vente.dart';

class NouvelleVentePage extends StatefulWidget {
  const NouvelleVentePage({super.key});

  @override
  State<NouvelleVentePage> createState() => _NouvelleVentePageState();
}

class _NouvelleVentePageState extends State<NouvelleVentePage> {
  final TextEditingController _articleController = TextEditingController();
  final TextEditingController _quantiteController = TextEditingController(text: '1');
  final TextEditingController _prixController = TextEditingController();
  final FocusNode _articleFocus = FocusNode();

  // Les articles ajoutés à la vente en cours (pas encore enregistrée).
  final List<LigneVente> _lignes = [];

  int get _total {
    int somme = 0;
    for (final ligne in _lignes) {
      somme += ligne.montant;
    }
    return somme;
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
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
      _lignes.add(
        LigneVente(article: article, quantite: quantite, prixUnitaire: prix),
      );
    });

    // On prépare les champs pour l'article suivant.
    _articleController.clear();
    _quantiteController.text = '1';
    _prixController.clear();
    _articleFocus.requestFocus();
  }

  Future<void> _enregistrer() async {
    if (_lignes.isEmpty) {
      _message('Ajoute au moins un article');
      return;
    }

    final vente = Vente(
      date: DateTime.now(),
      lignes: List.of(_lignes),
      montant: _total,
    );
    await BaseDeDonnees.ajouterVente(vente);
    if (!mounted) return;

    // On revient à la page précédente en disant "c'est enregistré" (true).
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _articleController.dispose();
    _quantiteController.dispose();
    _prixController.dispose();
    _articleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Ajouter cet article'),
          ),
          const SizedBox(height: 16),
          if (_lignes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Aucun article pour le moment.')),
            ),
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
      ),
      // Barre du bas : le total et le bouton pour enregistrer.
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
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Enregistrer la vente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
