import 'package:flutter_test/flutter_test.dart';
import 'package:sakoche/client.dart';
import 'package:sakoche/outils.dart';
import 'package:sakoche/vente.dart';

// Ces tests vérifient les calculs importants de l'application.
// On les lance avec la commande : flutter test
void main() {
  group('formaterMontant', () {
    test('sépare les milliers par des espaces', () {
      expect(formaterMontant(1250000), '1 250 000');
      expect(formaterMontant(45500), '45 500');
      expect(formaterMontant(500), '500');
    });

    test('affiche zéro', () {
      expect(formaterMontant(0), '0');
    });

    test('gère les montants négatifs', () {
      expect(formaterMontant(-1500), '-1 500');
      expect(formaterMontant(-100000), '-100 000');
    });
  });

  group('dates', () {
    test('memeJour reconnaît deux heures du même jour', () {
      expect(memeJour(DateTime(2026, 10, 23, 8, 0), DateTime(2026, 10, 23, 22, 30)), isTrue);
    });

    test('memeJour distingue deux jours différents', () {
      expect(memeJour(DateTime(2026, 10, 23), DateTime(2026, 10, 24)), isFalse);
    });

    test('dateDuJour écrit la date en français', () {
      expect(dateDuJour(DateTime(2026, 10, 22)), 'jeudi 22 octobre');
    });

    test('formaterDate met des zéros devant', () {
      expect(formaterDate(DateTime(2026, 3, 5)), '05/03/2026');
    });
  });

  group('Dette', () {
    test('le reste à payer = montant - remboursements', () {
      final dette = Dette(
        clientId: 1,
        montant: 10000,
        date: DateTime(2026, 10, 1),
        remboursements: [
          Remboursement(detteId: 1, montant: 3000, date: DateTime(2026, 10, 5)),
          Remboursement(detteId: 1, montant: 2000, date: DateTime(2026, 10, 8)),
        ],
      );
      expect(dette.rembourse, 5000);
      expect(dette.restant, 5000);
      expect(dette.estSoldee, isFalse);
    });

    test('une dette entièrement remboursée est soldée', () {
      final dette = Dette(
        clientId: 1,
        montant: 4000,
        date: DateTime(2026, 10, 1),
        remboursements: [
          Remboursement(detteId: 1, montant: 4000, date: DateTime(2026, 10, 2)),
        ],
      );
      expect(dette.restant, 0);
      expect(dette.estSoldee, isTrue);
    });

    test('une dette sans remboursement doit tout', () {
      final dette = Dette(clientId: 1, montant: 2500, date: DateTime(2026, 10, 1));
      expect(dette.restant, 2500);
    });
  });

  group('Vente.resume', () {
    test('affiche la note libre quand elle existe', () {
      final vente = Vente(
        date: DateTime(2026, 10, 23),
        lignes: const [],
        montant: 2500,
        note: 'Pommes',
      );
      expect(vente.resume, 'Pommes');
    });

    test('affiche simplement "Vente" sans note ni détail', () {
      final vente = Vente(date: DateTime(2026, 10, 23), lignes: const [], montant: 2500);
      expect(vente.resume, 'Vente');
    });

    test('reprend le détail des anciennes ventes par article', () {
      final vente = Vente(
        date: DateTime(2026, 10, 23),
        lignes: [LigneVente(article: 'Riz', quantite: 2, prixUnitaire: 500)],
        montant: 1000,
      );
      expect(vente.resume, '2 × Riz');
    });
  });

  group('LigneVente', () {
    test('le montant = quantité x prix unitaire', () {
      expect(LigneVente(article: 'Huile', quantite: 3, prixUnitaire: 1200).montant, 3600);
    });
  });
}
