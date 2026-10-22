import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_de_donnees.dart';
import 'client.dart';
import 'depenses_page.dart';
import 'outils.dart';

// Le compte d'un client : ce qu'il doit, son historique, et les boutons
// pour enregistrer un remboursement ou une ancienne dette.
class ClientPage extends StatefulWidget {
  final Client client;
  final Future<void> Function() onChange;

  const ClientPage({super.key, required this.client, required this.onChange});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  List<OperationClient> _operations = [];

  // La dette = tout ce qui s'ajoute, moins tout ce qui est remboursé.
  int get _dette {
    int somme = 0;
    for (final operation in _operations) {
      somme += operation.estCredit ? operation.montant : -operation.montant;
    }
    return somme;
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final operations = await BaseDeDonnees.lireOperations(widget.client.id!);
    if (!mounted) return;
    setState(() {
      _operations = operations;
    });
  }

  // Une boîte qui demande un montant. "maximum" empêche de rembourser plus que la dette.
  Future<int?> _demanderMontant({required String titre, int? maximum}) {
    final controller = TextEditingController();
    String? erreur;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(titre),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Montant (FCFA)',
                  errorText: erreur,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final montant = int.tryParse(controller.text.trim());
                    if (montant == null || montant <= 0) {
                      setStateDialog(() {
                        erreur = 'Entre un montant valide';
                      });
                      return;
                    }
                    if (maximum != null && montant > maximum) {
                      setStateDialog(() {
                        erreur = 'Plus que la dette (${formaterMontant(maximum)} FCFA)';
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, montant);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _ajouterOperation(String type) async {
    final dette = _dette;
    if (type == typeRemboursement && dette <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce client ne doit rien pour le moment')),
      );
      return;
    }

    final montant = await _demanderMontant(
      titre: type == typeRemboursement ? 'Remboursement reçu' : 'Ajouter une ancienne dette',
      maximum: type == typeRemboursement ? dette : null,
    );
    if (montant == null) return;

    await BaseDeDonnees.ajouterOperation(
      OperationClient(
        clientId: widget.client.id!,
        type: type,
        montant: montant,
        date: DateTime.now(),
      ),
    );
    await _charger();
    await widget.onChange();
  }

  Future<void> _supprimer() async {
    if (_dette > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce client doit encore ${formaterMontant(_dette)} FCFA. Enregistre d’abord son remboursement.',
          ),
        ),
      );
      return;
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce client ?'),
          content: Text('« ${widget.client.nom} » et son historique seront supprimés.'),
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
    if (confirme != true) return;

    await BaseDeDonnees.supprimerClient(widget.client.id!);
    await widget.onChange();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final dette = _dette;

    return Scaffold(
      appBar: AppBar(
        title: Text(client.nom),
        actions: [
          IconButton(
            tooltip: 'Supprimer le client',
            icon: const Icon(Icons.delete_outline),
            onPressed: _supprimer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ce que le client doit.
          Container(
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
                if (client.telephone.isNotEmpty) ...[
                  Text(client.telephone, style: const TextStyle(color: Color(0xFF5B6B63))),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Dette actuelle',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6B63)),
                ),
                Text(
                  dette > 0 ? '${formaterMontant(dette)} FCFA' : 'À jour',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: dette > 0 ? kRouge : kPrincipal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _ajouterOperation(typeRemboursement),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Enregistrer un remboursement'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _ajouterOperation(typeCredit),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une ancienne dette'),
          ),
          const SizedBox(height: 24),
          const Text('Historique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_operations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Aucune opération pour le moment.')),
            ),
          for (final operation in _operations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                operation.estCredit ? Icons.arrow_upward : Icons.arrow_downward,
                color: operation.estCredit ? kRouge : kPrincipal,
              ),
              title: Text(operation.estCredit ? 'Dette' : 'Remboursement'),
              subtitle: Text(formaterDateHeure(operation.date)),
              trailing: Text(
                '${operation.estCredit ? '+' : '−'} ${formaterMontant(operation.montant)} FCFA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: operation.estCredit ? kRouge : kPrincipal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
