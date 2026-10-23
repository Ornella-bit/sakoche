import 'package:flutter/material.dart';

import 'base_de_donnees.dart';
import 'client.dart';
import 'client_page.dart';
import 'depenses_page.dart';
import 'outils.dart';

// Demande le nom et le téléphone d'un nouveau client, l'enregistre
// et le renvoie (ou null si l'utilisatrice annule).
// Cette fonction sert à deux endroits : la page Clients et la vente à crédit.
Future<Client?> demanderNouveauClient(BuildContext context) async {
  final nomController = TextEditingController();
  final telephoneController = TextEditingController();
  String? erreur;

  final saisie = await showDialog<Client>(
    context: context,
    builder: (dialogContext) {
      // StatefulBuilder permet de mettre à jour la boîte (le message d'erreur).
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Nouveau client'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nom du client',
                    errorText: erreur,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telephoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone (facultatif)',
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
                  if (nom.isEmpty) {
                    setStateDialog(() {
                      erreur = 'Écris le nom du client';
                    });
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    Client(nom: nom, telephone: telephoneController.text.trim()),
                  );
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
    },
  );

  if (saisie == null) return null;
  final id = await BaseDeDonnees.ajouterClient(saisie.nom, saisie.telephone);
  return Client(id: id, nom: saisie.nom, telephone: saisie.telephone);
}

class ClientsPage extends StatelessWidget {
  final List<Client> clients;
  final Future<void> Function() onChange;

  const ClientsPage({super.key, required this.clients, required this.onChange});

  Future<void> _nouveauClient(BuildContext context) async {
    final client = await demanderNouveauClient(context);
    if (client != null) {
      await onChange();
    }
  }

  Future<void> _ouvrir(BuildContext context, Client client) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientPage(client: client, onChange: onChange),
      ),
    );
    await onChange(); // au retour, on met la liste à jour
  }

  @override
  Widget build(BuildContext context) {
    int totalDettes = 0;
    int nombreDebiteurs = 0;
    for (final client in clients) {
      if (client.dette > 0) {
        totalDettes += client.dette;
        nombreDebiteurs++;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nouveauClient(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nouveau client'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x1A0F5132), blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dettes en cours',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6B63)),
                ),
                Text(
                  '${formaterMontant(totalDettes)} FCFA',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: totalDettes > 0 ? kOcreFonce : kPrincipal,
                  ),
                ),
                Text(
                  nombreDebiteurs == 0
                      ? 'Aucun client ne te doit d’argent'
                      : nombreDebiteurs == 1
                          ? '1 client te doit de l’argent'
                          : '$nombreDebiteurs clients te doivent de l’argent',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: clients.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun client pour le moment.\nAjoute-en un, ou crée-le directement quand tu fais une vente à crédit.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: clients.length,
                    itemBuilder: (context, index) {
                      final client = clients[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: kPrincipal,
                          child: Text(
                            client.nom[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          client.nom,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: client.telephone.isEmpty ? null : Text(client.telephone),
                        trailing: client.dette > 0
                            ? Text(
                                '${formaterMontant(client.dette)} FCFA',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kRouge,
                                ),
                              )
                            : const Text('À jour', style: TextStyle(color: kPrincipal)),
                        onTap: () => _ouvrir(context, client),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
