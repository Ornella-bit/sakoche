// Un client, avec ce qu'il doit encore (toutes ses dettes moins tous ses remboursements).
class Client {
  final int? id;
  final String nom;
  final String telephone;
  final int dette; // 0 = à jour

  const Client({this.id, required this.nom, this.telephone = '', this.dette = 0});
}

// Un remboursement : une somme que le client a payée pour une dette précise.
class Remboursement {
  final int? id;
  final int detteId;
  final int montant;
  final DateTime date;

  const Remboursement({
    this.id,
    required this.detteId,
    required this.montant,
    required this.date,
  });
}

// Une dette d'un client : un motif (facultatif), un montant, une date,
// et la liste des remboursements déjà faits pour elle.
class Dette {
  final int? id;
  final int clientId;
  final String motif;
  final int montant;
  final DateTime date;
  final int? venteId; // renseigné si la dette vient d'une vente à crédit
  final List<Remboursement> remboursements;

  const Dette({
    this.id,
    required this.clientId,
    this.motif = '',
    required this.montant,
    required this.date,
    this.venteId,
    this.remboursements = const [],
  });

  // Ce qui a déjà été remboursé pour cette dette.
  int get rembourse {
    int somme = 0;
    for (final r in remboursements) {
      somme += r.montant;
    }
    return somme;
  }

  // Ce que le client doit encore pour cette dette.
  int get restant => montant - rembourse;

  bool get estSoldee => restant <= 0;
}

