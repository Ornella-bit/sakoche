// Une vente = un montant + le moment où elle a été faite.
class Vente {
  final int? id; // numéro donné automatiquement par la base de données
  final int montant;
  final DateTime date;

  Vente({this.id, required this.montant, required this.date});

  // Transforme une vente en "ligne" de tableau pour la ranger dans la base.
  Map<String, Object?> toMap() {
    return {
      'montant': montant,
      'date': date.toIso8601String(), // la date devient un texte, ex : 2026-10-21T14:05:00
    };
  }

  // Fait l'inverse : reconstruit une vente à partir d'une ligne de la base.
  factory Vente.fromMap(Map<String, Object?> ligne) {
    return Vente(
      id: ligne['id'] as int,
      montant: ligne['montant'] as int,
      date: DateTime.parse(ligne['date'] as String),
    );
  }
}
