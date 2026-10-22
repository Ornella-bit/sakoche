// Les deux sortes d'opérations sur le compte d'un client.
const String typeCredit = 'credit'; // le client doit de l'argent
const String typeRemboursement = 'remboursement'; // le client a payé

// Un client, avec ce qu'il doit encore.
class Client {
  final int? id;
  final String nom;
  final String telephone;
  final int dette; // ce que le client doit encore (0 = à jour)

  const Client({this.id, required this.nom, this.telephone = '', this.dette = 0});
}

// Une ligne du compte d'un client : une dette qui s'ajoute ou un remboursement.
class OperationClient {
  final int? id;
  final int clientId;
  final String type;
  final int montant;
  final DateTime date;

  const OperationClient({
    this.id,
    required this.clientId,
    required this.type,
    required this.montant,
    required this.date,
  });

  bool get estCredit => type == typeCredit;
}
