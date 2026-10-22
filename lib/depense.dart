// Une dépense : ce que le commerçant a payé pour son commerce.
class Depense {
  final int? id;
  final String libelle;
  final int montant;
  final String categorie;
  final DateTime date;

  const Depense({
    this.id,
    required this.libelle,
    required this.montant,
    required this.categorie,
    required this.date,
  });
}

// Les catégories proposées quand on enregistre une dépense.
const List<String> categoriesDepenses = [
  'Marchandises',
  'Transport',
  'Loyer',
  'Eau et électricité',
  'Salaires',
  'Autre',
];
