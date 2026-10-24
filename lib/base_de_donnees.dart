import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'client.dart';
import 'depense.dart';
import 'vente.dart';

class BaseDeDonnees {
  static Database? _base;

  // Où se trouve le fichier du carnet sur le téléphone.
  static Future<String> cheminFichier() async {
    final dossier = await getDatabasesPath();
    return join(dossier, 'sakoche.db');
  }

  // Ferme le carnet (utile avant de copier ou de remplacer le fichier).
  // Il se rouvre tout seul au prochain besoin.
  static Future<void> fermer() async {
    await _base?.close();
    _base = null;
  }

  static Future<Database> _ouvrir() async {
    if (_base != null) {
      return _base!;
    }

    final dossier = await getDatabasesPath();
    final chemin = join(dossier, 'sakoche.db');

    _base = await openDatabase(
      chemin,
      version: 7, // version 7 : une vente peut avoir une note libre
      onCreate: (db, version) async {
        await _creerTableVentes(db);
        await _creerTableLignes(db);
        await _creerTableDepenses(db);
        await _creerTableClients(db);
        await _creerTablesDettes(db);
      },
      onUpgrade: (db, ancienneVersion, nouvelleVersion) async {
        if (ancienneVersion < 2) {
          await _creerTableLignes(db);
        }
        if (ancienneVersion < 4) {
          await _creerTableDepenses(db);
        }
        if (ancienneVersion < 5) {
          await _creerTableClients(db);
        }
        if (ancienneVersion < 6) {
          await _creerTablesDettes(db);
          // Les téléphones qui avaient la version 5 ont un ancien tableau
          // de dettes : on reprend leurs données dans les nouveaux tableaux.
          if (ancienneVersion == 5) {
            await _migrerAnciennesDettes(db);
          }
        }
        if (ancienneVersion < 7) {
          // Les ventes déjà enregistrées reçoivent une note vide.
          await db.execute("ALTER TABLE ventes ADD COLUMN note TEXT NOT NULL DEFAULT ''");
        }
      },
    );
    return _base!;
  }

  static Future<void> _creerTableVentes(Database db) async {
    await db.execute('''
      CREATE TABLE ventes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        montant INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _creerTableLignes(Database db) async {
    await db.execute('''
      CREATE TABLE lignes_vente (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vente_id INTEGER NOT NULL,
        article TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        prix_unitaire INTEGER NOT NULL
      )
    ''');
  }

  static Future<void> _creerTableClients(Database db) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE COLLATE NOCASE,
        telephone TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  // Les dettes (chacune avec son motif et sa date) et leurs remboursements.
  // vente_id est rempli quand la dette vient d'une vente à crédit.
  static Future<void> _creerTablesDettes(Database db) async {
    await db.execute('''
      CREATE TABLE dettes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        motif TEXT NOT NULL DEFAULT '',
        montant INTEGER NOT NULL,
        date TEXT NOT NULL,
        vente_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE remboursements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dette_id INTEGER NOT NULL,
        montant INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  // Reprend l'ancien tableau "operations_client" : chaque ancien crédit devient
  // une dette, et chaque ancien remboursement solde les dettes les plus anciennes d'abord.
  static Future<void> _migrerAnciennesDettes(Database db) async {
    final anciennes = await db.query('operations_client', orderBy: 'date ASC');
    // Pour chaque client : la liste de ses dettes sous la forme [numéro, reste à payer].
    final dettesParClient = <int, List<List<int>>>{};

    for (final operation in anciennes) {
      final clientId = operation['client_id'] as int;
      final montant = operation['montant'] as int;
      final date = operation['date'] as String;
      final liste = dettesParClient.putIfAbsent(clientId, () => <List<int>>[]);

      if (operation['type'] == 'credit') {
        final idDette = await db.insert('dettes', {
          'client_id': clientId,
          'motif': '',
          'montant': montant,
          'date': date,
        });
        liste.add([idDette, montant]);
      } else {
        int aPayer = montant;
        for (final dette in liste) {
          if (aPayer <= 0) break;
          if (dette[1] <= 0) continue;
          final part = dette[1] < aPayer ? dette[1] : aPayer;
          await db.insert('remboursements', {
            'dette_id': dette[0],
            'montant': part,
            'date': date,
          });
          dette[1] -= part;
          aPayer -= part;
        }
      }
    }
    await db.execute('DROP TABLE operations_client');
  }

  static Future<void> _creerTableDepenses(Database db) async {
    await db.execute('''
      CREATE TABLE depenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        libelle TEXT NOT NULL,
        montant INTEGER NOT NULL,
        categorie TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
  }

  // ---------- Ventes ----------

  // Enregistre une vente : un montant, une note libre facultative ("pour quoi ?")
  // et, si elle est à crédit, la dette du client.
  static Future<void> ajouterVente(Vente vente) async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      final idVente = await txn.insert('ventes', {
        'montant': vente.montant,
        'note': vente.note,
        'date': vente.date.toIso8601String(),
      });
      // Le détail par article n'existe plus pour les nouvelles ventes,
      // mais on garde la possibilité d'enregistrer des lignes (anciennes données).
      for (final ligne in vente.lignes) {
        await txn.insert('lignes_vente', {
          'vente_id': idVente,
          'article': ligne.article,
          'quantite': ligne.quantite,
          'prix_unitaire': ligne.prixUnitaire,
        });
      }
      // Vente à crédit : ce qui n'est pas payé devient une dette du client.
      // Le motif de la dette reprend la note de la vente.
      if (vente.clientId != null && vente.credit > 0) {
        await txn.insert('dettes', {
          'client_id': vente.clientId,
          'motif': vente.note.isNotEmpty
              ? vente.note
              : (vente.lignes.isEmpty ? '' : vente.resume),
          'montant': vente.credit,
          'date': vente.date.toIso8601String(),
          'vente_id': idVente,
        });
      }
    });
  }

  static Future<List<Vente>> lireVentes() async {
    final db = await _ouvrir();
    final lignesVentes = await db.query('ventes', orderBy: 'date DESC');

    // Les dettes liées à une vente à crédit : on les range par numéro de vente.
    final dettesLiees = await db.query('dettes', where: 'vente_id IS NOT NULL');
    final detteParVente = <int, Map<String, Object?>>{};
    for (final dette in dettesLiees) {
      detteParVente[dette['vente_id'] as int] = dette;
    }

    final resultat = <Vente>[];
    for (final v in lignesVentes) {
      final id = v['id'] as int;
      final lignes = await db.query(
        'lignes_vente',
        where: 'vente_id = ?',
        whereArgs: [id],
      );
      final dette = detteParVente[id];
      resultat.add(
        Vente(
          id: id,
          date: DateTime.parse(v['date'] as String),
          montant: v['montant'] as int,
          note: v['note'] as String,
          clientId: dette == null ? null : dette['client_id'] as int,
          credit: dette == null ? 0 : dette['montant'] as int,
          lignes: lignes
              .map(
                (l) => LigneVente(
                  article: l['article'] as String,
                  quantite: l['quantite'] as int,
                  prixUnitaire: l['prix_unitaire'] as int,
                ),
              )
              .toList(),
        ),
      );
    }
    return resultat;
  }

  // Corrige une vente. Si le montant change, l'ancien détail par article
  // n'a plus de sens : on l'efface.
  static Future<void> modifierVente({
    required int id,
    required int montant,
    required String note,
    required DateTime date,
    required bool effacerLignes,
  }) async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      await txn.update(
        'ventes',
        {'montant': montant, 'note': note, 'date': date.toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      if (effacerLignes) {
        await txn.delete('lignes_vente', where: 'vente_id = ?', whereArgs: [id]);
      }
    });
  }

  // Supprime une vente. Si elle était à crédit, la dette liée est supprimée aussi.
  static Future<void> supprimerVente(int id) async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM remboursements WHERE dette_id IN (SELECT id FROM dettes WHERE vente_id = ?)',
        [id],
      );
      await txn.delete('dettes', where: 'vente_id = ?', whereArgs: [id]);
      await txn.delete('lignes_vente', where: 'vente_id = ?', whereArgs: [id]);
      await txn.delete('ventes', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Les dernières notes utilisées (sans doublons) : elles sont proposées
  // comme raccourcis quand on enregistre une vente.
  static Future<List<String>> lireNotesRecentes() async {
    final db = await _ouvrir();
    final lignes = await db.rawQuery('''
      SELECT note, MAX(date) AS derniere
      FROM ventes
      WHERE note != ''
      GROUP BY note COLLATE NOCASE
      ORDER BY derniere DESC
      LIMIT 8
    ''');
    return lignes.map((l) => l['note'] as String).toList();
  }

  // Supprime toutes les ventes, les dépenses et les dettes. La liste des clients reste.
  static Future<void> toutEffacer() async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      await txn.delete('lignes_vente');
      await txn.delete('ventes');
      await txn.delete('depenses');
      await txn.delete('remboursements');
      await txn.delete('dettes');
    });
  }

  // ---------- Clients et dettes ----------

  // Lit les clients avec ce que chacun doit : toutes ses dettes
  // moins tous ses remboursements (calculé par la base elle-même).
  static Future<List<Client>> lireClients() async {
    final db = await _ouvrir();
    final lignes = await db.rawQuery('''
      SELECT c.id, c.nom, c.telephone,
        COALESCE((SELECT SUM(d.montant) FROM dettes d WHERE d.client_id = c.id), 0)
        - COALESCE((SELECT SUM(r.montant)
                    FROM remboursements r
                    JOIN dettes d ON d.id = r.dette_id
                    WHERE d.client_id = c.id), 0) AS dette
      FROM clients c
      ORDER BY c.nom COLLATE NOCASE
    ''');
    return lignes
        .map(
          (l) => Client(
            id: l['id'] as int,
            nom: l['nom'] as String,
            telephone: l['telephone'] as String,
            dette: (l['dette'] as num).toInt(),
          ),
        )
        .toList();
  }

  // Ajoute un client et renvoie son numéro. Si un client du même nom existe déjà,
  // on renvoie simplement le numéro de celui-ci.
  static Future<int> ajouterClient(String nom, String telephone) async {
    final db = await _ouvrir();
    final existant = await db.query('clients', where: 'nom = ?', whereArgs: [nom]);
    if (existant.isNotEmpty) {
      return existant.first['id'] as int;
    }
    return db.insert('clients', {'nom': nom, 'telephone': telephone});
  }

  static Future<void> supprimerClient(int id) async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM remboursements WHERE dette_id IN (SELECT id FROM dettes WHERE client_id = ?)',
        [id],
      );
      await txn.delete('dettes', where: 'client_id = ?', whereArgs: [id]);
      await txn.delete('clients', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Lit les dettes (celles d'un client, ou toutes si on ne donne pas de client),
  // chacune avec ses remboursements. La plus récente d'abord.
  static Future<List<Dette>> lireDettes([int? clientId]) async {
    final db = await _ouvrir();
    final lignes = clientId == null
        ? await db.query('dettes', orderBy: 'date DESC')
        : await db.query(
            'dettes',
            where: 'client_id = ?',
            whereArgs: [clientId],
            orderBy: 'date DESC',
          );
    final lignesRemboursements = await db.query('remboursements', orderBy: 'date ASC');

    // On range les remboursements par dette.
    final parDette = <int, List<Remboursement>>{};
    for (final r in lignesRemboursements) {
      final detteId = r['dette_id'] as int;
      parDette.putIfAbsent(detteId, () => <Remboursement>[]).add(
            Remboursement(
              id: r['id'] as int,
              detteId: detteId,
              montant: r['montant'] as int,
              date: DateTime.parse(r['date'] as String),
            ),
          );
    }

    return lignes
        .map(
          (l) => Dette(
            id: l['id'] as int,
            clientId: l['client_id'] as int,
            motif: l['motif'] as String,
            montant: l['montant'] as int,
            date: DateTime.parse(l['date'] as String),
            venteId: l['vente_id'] as int?,
            remboursements: parDette[l['id'] as int] ?? const [],
          ),
        )
        .toList();
  }

  static Future<void> ajouterDette(Dette dette) async {
    final db = await _ouvrir();
    await db.insert('dettes', {
      'client_id': dette.clientId,
      'motif': dette.motif,
      'montant': dette.montant,
      'date': dette.date.toIso8601String(),
      'vente_id': dette.venteId,
    });
  }

  static Future<void> modifierDette({
    required int id,
    required String motif,
    required int montant,
    required DateTime date,
  }) async {
    final db = await _ouvrir();
    await db.update(
      'dettes',
      {'motif': motif, 'montant': montant, 'date': date.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Supprime une dette et tous ses remboursements.
  static Future<void> supprimerDette(int id) async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      await txn.delete('remboursements', where: 'dette_id = ?', whereArgs: [id]);
      await txn.delete('dettes', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> ajouterRemboursement(Remboursement remboursement) async {
    final db = await _ouvrir();
    await db.insert('remboursements', {
      'dette_id': remboursement.detteId,
      'montant': remboursement.montant,
      'date': remboursement.date.toIso8601String(),
    });
  }

  // ---------- Dépenses ----------

  static Future<void> ajouterDepense(Depense depense) async {
    final db = await _ouvrir();
    await db.insert('depenses', {
      'libelle': depense.libelle,
      'montant': depense.montant,
      'categorie': depense.categorie,
      'date': depense.date.toIso8601String(),
    });
  }

  static Future<List<Depense>> lireDepenses() async {
    final db = await _ouvrir();
    final lignes = await db.query('depenses', orderBy: 'date DESC');
    return lignes
        .map(
          (l) => Depense(
            id: l['id'] as int,
            libelle: l['libelle'] as String,
            montant: l['montant'] as int,
            categorie: l['categorie'] as String,
            date: DateTime.parse(l['date'] as String),
          ),
        )
        .toList();
  }

  static Future<void> supprimerDepense(int id) async {
    final db = await _ouvrir();
    await db.delete('depenses', where: 'id = ?', whereArgs: [id]);
  }
}
