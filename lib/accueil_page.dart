import 'package:flutter/material.dart';

import 'client.dart';
import 'depense.dart';
import 'depenses_page.dart';
import 'outils.dart';
import 'profil.dart';
import 'vente.dart';

// L'accueil est une page FIXE : elle ne défile pas.
// Le graphique de la semaine prend toute la place qui reste.
class AccueilPage extends StatelessWidget {
  final List<Vente> ventes;
  final List<Depense> depenses;
  final List<Dette> dettes;
  final Profil profil;
  final VoidCallback onNouvelleVente;
  final VoidCallback onOuvrirMoi;

  const AccueilPage({
    super.key,
    required this.ventes,
    required this.depenses,
    required this.dettes,
    required this.profil,
    required this.onNouvelleVente,
    required this.onOuvrirMoi,
  });

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();

    // Total des ventes d'aujourd'hui.
    int totalJour = 0;
    for (final vente in ventes) {
      if (memeJour(vente.date, maintenant)) {
        totalJour += vente.montant;
      }
    }

    // Dépenses d'aujourd'hui.
    int depensesJour = 0;
    for (final depense in depenses) {
      if (memeJour(depense.date, maintenant)) {
        depensesJour += depense.montant;
      }
    }

    // Les dettes : ce qui est resté à payer sur les ventes d'aujourd'hui,
    // ce qui a été remboursé aujourd'hui, et ce que les clients doivent encore en tout.
    int creditsJour = 0;
    int remboursementsJour = 0;
    int dettesTotal = 0;
    for (final dette in dettes) {
      dettesTotal += dette.restant;
      if (dette.venteId != null && memeJour(dette.date, maintenant)) {
        creditsJour += dette.montant;
      }
      for (final remboursement in dette.remboursements) {
        if (memeJour(remboursement.date, maintenant)) {
          remboursementsJour += remboursement.montant;
        }
      }
    }

    // Solde = l'argent réellement reçu aujourd'hui moins les dépenses :
    // les ventes à crédit ne comptent pas tant qu'elles ne sont pas payées.
    final solde = totalJour - creditsJour + remboursementsJour - depensesJour;

    // Les 7 derniers jours (le plus ancien en premier, aujourd'hui en dernier)
    // et le total des ventes de chacun.
    final jours = List.generate(
      7,
      (i) => maintenant.subtract(Duration(days: 6 - i)),
    );
    final totaux = <int>[];
    for (final jour in jours) {
      int somme = 0;
      for (final vente in ventes) {
        if (memeJour(vente.date, jour)) {
          somme += vente.montant;
        }
      }
      totaux.add(somme);
    }
    int totalSemaine = 0;
    int maximum = 0;
    for (final t in totaux) {
      totalSemaine += t;
      if (t > maximum) maximum = t;
    }

    final nomComplet = profil.nom.trim();
    final prenom = nomComplet.isEmpty ? '' : nomComplet.split(' ').first;
    final salutation = prenom.isEmpty ? 'Bonjour' : 'Bonjour, $prenom';

    // Une colonne qui s'étire sur toute la largeur et toute la hauteur de l'écran.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ----- En-tête illustré -----
        Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: VaguesPainter())),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Le bouton "trois barres" qui ouvre le menu.
                        Builder(
                          builder: (context) => IconButton(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: const Icon(Icons.menu, color: kPrincipal, size: 28),
                            tooltip: 'Menu',
                          ),
                        ),
                        GestureDetector(
                          onTap: onOuvrirMoi,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: kPrincipal,
                            child: nomComplet.isEmpty
                                ? const Icon(Icons.person, size: 20, color: Colors.white)
                                : Text(
                                    nomComplet[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            'Sakoche',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: kOcreFonce,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$salutation · ${dateDuJour(maintenant)}',
                            style: const TextStyle(fontSize: 14, color: kPrincipal),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Ventes du jour',
                            style: TextStyle(fontSize: 12, color: Color(0xFF3B4552)),
                          ),
                          Text.rich(
                            TextSpan(
                              text: formaterMontant(totalJour),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: kPrincipal,
                              ),
                              children: const [
                                TextSpan(text: ' FCFA', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ----- Dépenses et solde du jour -----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CarteChiffre(
                    titre: 'Dépenses du jour',
                    montant: depensesJour,
                    couleur: kRouge,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CarteChiffre(
                    titre: 'Solde du jour',
                    montant: solde,
                    couleur: solde >= 0 ? kPrincipal : kRouge,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CarteChiffre(
                    titre: 'Dettes clients',
                    montant: dettesTotal,
                    couleur: kOcreFonce,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ----- Graphique de la semaine : il occupe toute la place restante -----
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _CarteSemaine(
              jours: jours,
              totaux: totaux,
              maximum: maximum,
              totalSemaine: totalSemaine,
            ),
          ),
        ),

        // ----- Bouton -----
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: onNouvelleVente,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle vente'),
          ),
        ),
      ],
    );
  }
}

// La carte "Cette semaine". Les barres s'adaptent à la hauteur disponible.
class _CarteSemaine extends StatelessWidget {
  final List<DateTime> jours;
  final List<int> totaux;
  final int maximum;
  final int totalSemaine;

  const _CarteSemaine({
    required this.jours,
    required this.totaux,
    required this.maximum,
    required this.totalSemaine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F5132), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cette semaine', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '${formaterMontant(totalSemaine)} FCFA',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: kPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // LayoutBuilder nous donne la hauteur réellement disponible pour les barres.
          Expanded(
            child: LayoutBuilder(
              builder: (context, contraintes) {
                // On garde 30 de hauteur pour les lettres des jours sous les barres.
                final hauteurMax =
                    contraintes.maxHeight > 34 ? contraintes.maxHeight - 30 : 4.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < 7; i++)
                      Expanded(
                        child: _Barre(
                          hauteur: maximum == 0
                              ? 4
                              : 4 + (hauteurMax - 4) * totaux[i] / maximum,
                          etiquette: initialeJour(jours[i]),
                          aujourdhui: i == 6,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Une petite carte avec un titre et un montant.
class _CarteChiffre extends StatelessWidget {
  final String titre;
  final int montant;
  final Color couleur;

  const _CarteChiffre({
    required this.titre,
    required this.montant,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Text(titre, style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B63))),
          const SizedBox(height: 2),
          // FittedBox réduit un peu le texte s'il est trop large pour la carte.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${formaterMontant(montant)} F',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

// Une barre du graphique de la semaine.
class _Barre extends StatelessWidget {
  final double hauteur;
  final String etiquette;
  final bool aujourdhui;

  const _Barre({
    required this.hauteur,
    required this.etiquette,
    required this.aujourdhui,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 22,
          height: hauteur,
          decoration: BoxDecoration(
            // Aujourd'hui en vert plein, les autres jours plus clairs.
            color: aujourdhui ? kPrincipal : const Color(0x730F5132),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(etiquette, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

// Dessine l'illustration de l'en-tête : un fond clair, deux vagues et un soleil.
// Les coordonnées sont pensées pour un dessin de 360 x 200,
// puis étirées pour s'adapter à la taille réelle de l'en-tête.
class VaguesPainter extends CustomPainter {
  const VaguesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 360;
    final sy = size.height / 200;
    double x(double v) => v * sx;
    double y(double v) => v * sy;

    // Fond clair.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE4F0E8));

    // Première vague : vert très léger.
    final vague1 = Path()
      ..moveTo(x(0), y(120))
      ..cubicTo(x(60), y(70), x(120), y(160), x(200), y(110))
      ..cubicTo(x(280), y(60), x(310), y(80), x(360), y(100))
      ..lineTo(x(360), y(200))
      ..lineTo(x(0), y(200))
      ..close();
    canvas.drawPath(vague1, Paint()..color = const Color(0x240F5132));

    // Deuxième vague : jaune.
    final vague2 = Path()
      ..moveTo(x(0), y(150))
      ..cubicTo(x(80), y(110), x(150), y(180), x(230), y(145))
      ..cubicTo(x(310), y(110), x(320), y(125), x(360), y(140))
      ..lineTo(x(360), y(200))
      ..lineTo(x(0), y(200))
      ..close();
    canvas.drawPath(vague2, Paint()..color = const Color(0x8CF7B500));

    // Le soleil.
    canvas.drawCircle(
      Offset(x(310), y(48)),
      26 * sx,
      Paint()..color = const Color(0x59F7B500),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
