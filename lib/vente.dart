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
  final String note; // texte libre facultatif : "pour quoi ?" (ex : pommes)
  final int? clientId; // le client, si la vente est (en partie) à crédit
  final int credit; // la part qui reste à payer (0 si tout est payé)

  Vente({
    this.id,
    required this.date,
    required this.lignes,
    required this.montant,
    this.note = '',
    this.clientId,
    this.credit = 0,
  });

  // Résumé en une ligne, ex : "2 × riz, 1 × huile".
  // Ce qu'on affiche pour décrire la vente : le détail des articles (anciennes ventes),
  // sinon la note libre, sinon simplement "Vente".
  String get resume {
    if (lignes.isNotEmpty) {
      return lignes.map((l) => '${l.quantite} × ${l.article}').join(', ');
    }
    if (note.isNotEmpty) {
      return note;
    }
    return 'Vente';
  }
}
