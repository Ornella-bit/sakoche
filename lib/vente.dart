// Une ligne de vente = un article vendu : "3 × sachet d’eau à 100 FCFA".
class LigneVente {
  final String article;
  final int quantite;
  final int prixUnitaire;

  LigneVente({
    required this.article,
    required this.quantite,
    required this.prixUnitaire,
  });

  int get montant => quantite * prixUnitaire;
}

// Une vente = une date + plusieurs articles + le total.
class Vente {
  final int? id;
  final DateTime date;
  final List<LigneVente> lignes;
  final int montant; // le total de la vente

  Vente({
    this.id,
    required this.date,
    required this.lignes,
    required this.montant,
  });

  // Résumé en une ligne, ex : "2 × riz, 1 × huile".
  String get resume {
    if (lignes.isEmpty) {
      return 'Vente sans détail';
    }
    return lignes.map((l) => '${l.quantite} × ${l.article}').join(', ');
  }
}