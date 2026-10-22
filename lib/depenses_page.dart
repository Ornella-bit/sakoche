import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_de_donnees.dart';
import 'depense.dart';
import 'outils.dart';

const Color kRouge = Color(0xFFB3261E);

class DepensesPage extends StatelessWidget {
  final List<Depense> depenses;
  final Future<void> Function() onChange; // prévient la page principale d'un changement

  const DepensesPage({super.key, required this.depenses, required this.onChange});

  IconData _icone(String categorie) {
    switch (categorie) {
      case 'Marchandises':
        return Icons.shopping_basket_outlined;
      case 'Transport':
        return Icons.local_shipping_outlined;
      case 'Loyer':
        return Icons.storefront_outlined;
      case 'Eau et électricité':
        return Icons.bolt_outlined;
      case 'Salaires':
        return Icons.groups_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Future<void> _ajouter(BuildContext context) async {
    final depense = await showModalBottomSheet<Depense>(
      context: context,
      isScrollControlled: true, // pour que la feuille monte au-dessus du clavier
      showDragHandle: true,
      builder: (_) => const _FormulaireDepense(),
    );
    if (depense == null) return;
    await BaseDeDonnees.ajouterDepense(depense);
    await onChange();
  }

  Future<void> _supprimer(BuildContext context, Depense depense) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer cette dépense ?'),
          content: Text(
            '« ${depense.libelle} » (${formaterMontant(depense.montant)} FCFA) sera supprimée.',
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
    if (confirme != true || depense.id == null) return;
    await BaseDeDonnees.supprimerDepense(depense.id!);
    await onChange();
  }

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    int totalJour = 0;
    for (final d in depenses) {
      if (memeJour(d.date, maintenant)) {
        totalJour += d.montant;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dépenses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ajouter(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle dépense'),
      ),
      body: Column(
        children: [
          // Résumé du jour.
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
                  'Dépenses du jour',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6B63)),
                ),
                Text(
                  '${formaterMontant(totalJour)} FCFA',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: kRouge,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: depenses.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucune dépense pour le moment.\nNote ici ce que tu paies : marchandises, transport, loyer...',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: depenses.length,
                    itemBuilder: (context, index) {
                      final depense = depenses[index];
                      return ListTile(
                        leading: Icon(_icone(depense.categorie), color: kRouge),
                        title: Text(
                          depense.libelle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${depense.categorie} · ${formaterDateHeure(depense.date)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${formaterMontant(depense.montant)} FCFA',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kRouge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _supprimer(context, depense),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// La feuille qui monte du bas pour saisir une dépense.
class _FormulaireDepense extends StatefulWidget {
  const _FormulaireDepense();

  @override
  State<_FormulaireDepense> createState() => _FormulaireDepenseState();
}

class _FormulaireDepenseState extends State<_FormulaireDepense> {
  final TextEditingController _libelleController = TextEditingController();
  final TextEditingController _montantController = TextEditingController();
  String _categorie = categoriesDepenses.first;
  String? _erreurMontant;

  void _enregistrer() {
    final montant = int.tryParse(_montantController.text.trim());
    if (montant == null || montant <= 0) {
      setState(() {
        _erreurMontant = 'Entre un montant valide, par exemple 5000';
      });
      return;
    }
    final libelle = _libelleController.text.trim();
    // Si aucun nom n'est donné, on utilise la catégorie comme nom.
    Navigator.pop(
      context,
      Depense(
        libelle: libelle.isEmpty ? _categorie : libelle,
        montant: montant,
        categorie: _categorie,
        date: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _libelleController.dispose();
    _montantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom, // laisse la place au clavier
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nouvelle dépense',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final categorie in categoriesDepenses)
                ChoiceChip(
                  label: Text(categorie),
                  selected: _categorie == categorie,
                  onSelected: (_) {
                    setState(() {
                      _categorie = categorie;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _libelleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Détail (facultatif)',
              hintText: 'Ex : 2 sacs de riz au marché',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _montantController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Montant (FCFA)',
              errorText: _erreurMontant,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _enregistrer(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _enregistrer,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Enregistrer la dépense'),
          ),
        ],
      ),
    );
  }
}
