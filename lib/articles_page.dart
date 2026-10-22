import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'article.dart';
import 'base_de_donnees.dart';
import 'outils.dart';

// La page "Mes articles" : voir, ajouter, modifier et supprimer les articles du catalogue.
class ArticlesPage extends StatefulWidget {
  const ArticlesPage({super.key});

  @override
  State<ArticlesPage> createState() => _ArticlesPageState();
}

class _ArticlesPageState extends State<ArticlesPage> {
  List<Article> _articles = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final articles = await BaseDeDonnees.lireArticles();
    if (!mounted) return;
    setState(() {
      _articles = articles;
    });
  }

  // La boîte de dialogue pour ajouter un article (existant == null)
  // ou modifier un article existant.
  Future<void> _formulaire([Article? existant]) async {
    final nomController = TextEditingController(text: existant?.nom ?? '');
    final prixController = TextEditingController(
      text: existant == null ? '' : existant.prix.toString(),
    );

    final resultat = await showDialog<Article>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existant == null ? 'Nouvel article' : 'Modifier l’article'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nom de l’article',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prixController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Prix habituel (FCFA)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final nom = nomController.text.trim();
                final prix = int.tryParse(prixController.text.trim());
                // Si le nom ou le prix manque, on ne ferme pas la boîte.
                if (nom.isEmpty || prix == null || prix <= 0) return;
                Navigator.pop(dialogContext, Article(id: existant?.id, nom: nom, prix: prix));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );

    if (resultat == null) return;
    await BaseDeDonnees.enregistrerArticle(resultat);
    await _charger();
  }

  Future<void> _supprimer(Article article) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer cet article ?'),
          content: Text(
            '« ${article.nom} » sera retiré du catalogue. Tes anciennes ventes ne changent pas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirme != true || article.id == null) return;
    await BaseDeDonnees.supprimerArticle(article.id!);
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes articles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formulaire(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel article'),
      ),
      body: _articles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aucun article pour le moment.\n\nIls s’ajoutent tout seuls quand tu enregistres des ventes, ou utilise le bouton « Nouvel article ».',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _articles.length,
              itemBuilder: (context, index) {
                final article = _articles[index];
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined, color: kPrincipal),
                  title: Text(
                    article.nom,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${formaterMontant(article.prix)} FCFA'),
                  onTap: () => _formulaire(article),
                  trailing: IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _supprimer(article),
                  ),
                );
              },
            ),
    );
  }
}
