import 'package:flutter/material.dart';

import 'client.dart';
import 'depense.dart';
import 'depenses_page.dart';
import 'outils.dart';
import 'vente.dart';

// Les rapports : ce qui est entré, ce qui est sorti, et ce qui rapporte le plus.
class RapportsPage extends StatefulWidget {
  final List<Vente> ventes;
  final List<Depense> depenses;
  final List<Dette> dettes;

  const RapportsPage({
    super.key,
    required this.ventes,
    required this.depenses,
    required this.dettes,
  });

  @override
  State<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends State<RapportsPage> {
  int _jours = 7; // 1 = aujourd'hui, 7 = les 7 derniers jours, 30 = les 30 derniers jours

  // "05/03"
  String _court(DateTime date) {
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois';
  }

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final debut = aujourdhui.subtract(Duration(days: _jours - 1));
    bool dansPeriode(DateTime date) => !date.isBefore(debut);

    // ----- Les ventes de la période, et ce pour quoi elles ont été faites -----
    int totalVentes = 0;
    int nombreVentes = 0;
    final totauxParMotif = <String, int>{};
    final nomsParMotif = <String, String>{};

    void compter(String nom, int montant) {
      final cle = nom.trim().toLowerCase(); // "Pommes" et "pommes" comptent ensemble
      totauxParMotif[cle] = (totauxParMotif[cle] ?? 0) + montant;
      nomsParMotif.putIfAbsent(cle, () => nom.trim());
    }

    for (final vente in widget.ventes) {
      if (!dansPeriode(vente.date)) continue;
      totalVentes += vente.montant;
      nombreVentes++;
      if (vente.note.trim().isNotEmpty) {
        compter(vente.note, vente.montant);
      } else if (vente.lignes.isNotEmpty) {
        for (final ligne in vente.lignes) {
          compter(ligne.article, ligne.montant);
        }
      } else {
        compter('Sans précision', vente.montant);
      }
    }

    // ----- Les dépenses de la période -----
    int totalDepenses = 0;
    for (final depense in widget.depenses) {
      if (dansPeriode(depense.date)) {
        totalDepenses += depense.montant;
      }
    }

    // ----- L'argent réellement reçu : les ventes moins ce qui est resté à crédit,
    // plus les remboursements reçus. Puis le solde = argent reçu moins dépenses. -----
    int credits = 0;
    int remboursements = 0;
    int dettesARecevoir = 0;
    for (final dette in widget.dettes) {
      dettesARecevoir += dette.restant;
      if (dette.venteId != null && dansPeriode(dette.date)) {
        credits += dette.montant;
      }
      for (final remboursement in dette.remboursements) {
        if (dansPeriode(remboursement.date)) {
          remboursements += remboursement.montant;
        }
      }
    }
    final solde = totalVentes - credits + remboursements - totalDepenses;

    // ----- Les ventes de chaque jour (pour le graphique) -----
    final jours = List.generate(_jours, (i) => debut.add(Duration(days: i)));
    final totauxJours = <int>[];
    int maximumJour = 0;
    for (final jour in jours) {
      int somme = 0;
      for (final vente in widget.ventes) {
        if (memeJour(vente.date, jour)) {
          somme += vente.montant;
        }
      }
      totauxJours.add(somme);
      if (somme > maximumJour) maximumJour = somme;
    }

    // ----- Le classement : ce qui a le plus rapporté -----
    final classement = totauxParMotif.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final meilleurs = classement.take(5).toList();
    final plusGrand = meilleurs.isEmpty ? 1 : meilleurs.first.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Rapports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('Aujourd’hui')),
              ButtonSegment(value: 7, label: Text('7 jours')),
              ButtonSegment(value: 30, label: Text('30 jours')),
            ],
            selected: {_jours},
            onSelectionChanged: (choix) {
              setState(() {
                _jours = choix.first;
              });
            },
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Carte(
                    titre: 'Ventes',
                    valeur: '${formaterMontant(totalVentes)} FCFA',
                    couleur: kPrincipal,
                    detail: nombreVentes <= 1 ? '$nombreVentes vente' : '$nombreVentes ventes',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Carte(
                    titre: 'Dépenses',
                    valeur: '${formaterMontant(totalDepenses)} FCFA',
                    couleur: kRouge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Carte(
                    titre: 'Solde',
                    valeur: '${formaterMontant(solde)} FCFA',
                    couleur: solde >= 0 ? kPrincipal : kRouge,
                    detail: 'argent reçu − dépenses',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Carte(
                    titre: 'Dettes à recevoir',
                    valeur: '${formaterMontant(dettesARecevoir)} FCFA',
                    couleur: kOcreFonce,
                    detail: 'tous les clients',
                  ),
                ),
              ],
            ),
          ),

          // ----- Graphique : seulement quand la période a plusieurs jours -----
          if (_jours > 1) ...[
            const SizedBox(height: 16),
            _boite(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ventes par jour', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (int i = 0; i < jours.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: _jours > 7 ? 1 : 4),
                              child: Container(
                                height: maximumJour == 0
                                    ? 3
                                    : 3 + 117 * totauxJours[i] / maximumJour,
                                decoration: BoxDecoration(
                                  color: i == jours.length - 1
                                      ? kPrincipal
                                      : const Color(0x730F5132),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_court(jours.first), style: const TextStyle(fontSize: 11)),
                      Text(_court(jours.last), style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // ----- Ce qui a le plus rapporté -----
          const SizedBox(height: 16),
          _boite(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ce qui a le plus rapporté',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (meilleurs.isEmpty) const Text('Aucune vente sur cette période.'),
                for (final entree in meilleurs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(nomsParMotif[entree.key] ?? entree.key)),
                            Text(
                              '${formaterMontant(entree.value)} FCFA',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: entree.value / plusGrand,
                          minHeight: 6,
                          color: kPrincipal,
                          backgroundColor: const Color(0x1A0F5132),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Une boîte blanche aux coins arrondis.
  Widget _boite(Widget contenu) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F5132), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: contenu,
    );
  }
}

// Une petite carte : un titre, un montant, et une précision facultative.
class _Carte extends StatelessWidget {
  final String titre;
  final String valeur;
  final Color couleur;
  final String? detail;

  const _Carte({
    required this.titre,
    required this.valeur,
    required this.couleur,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F5132), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B63))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: couleur),
            ),
          ),
          if (detail != null)
            Text(detail!, style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B63))),
        ],
      ),
    );
  }
}
