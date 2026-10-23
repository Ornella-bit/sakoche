import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'article.dart';
import 'client.dart';
import 'depense.dart';
import 'vente.dart';

class BaseDeDonnees {
  static Database? _base;

  static Future<Database> _ouvrir() async {
    if (_base != null) {
      return _base!;
    }

    final dossier = await getDatabasesPath();
    final chemin = join(dossier, 'sakoche.db');

    _base = await openDatabase(
      chemin,
      version: 6, // version 6 : chaque dette a son motif, sa date et ses remboursements
      onCreate: (db, version) async {
        await _creerTableVentes(db);
        await _creerTableLignes(db);
        await _creerTableArticles(db);
        await _creerTableDepenses(db);
        await _creerTableClients(db);
        await _creerTablesDettes(db);
      },
      onUpgrade: (db, ancienneVersion, nouvelleVersion) async {
        if (ancienneVersion < 2) {
          await _creerTableLignes(db);
        }
        if (ancienneVersion < 3) {
          await _creerTableArticles(db);
          // On remplit le catalogue avec les articles déjà vendus,
          // avec le dernier prix utilisé pour chacun.
          await db.execute('''
            INSERT OR REPLACE INTO articles (nom, prix)
            SELECT article, prix_unitaire FROM lignes_vente
            WHERE id IN (SELECT MAX(id) FROM lignes_vente GROUP BY article)
          ''');
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
      },
    );
    return _base!;
  }

  static Future<void> _creerTableVentes(Database db) async {
    await db.execute('''
      CREATE TABLE ventes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        montant INTEGER NOT NULL,
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

  // UNIQUE + NOCASE : "Riz" et "riz" sont le même article (un seul exemplaire).
  static Future<void> _creerTableArticles(Database db) async {
    await db.execute('''
      CREATE TABLE articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE COLLATE NOCASE,
        prix INTEGER NOT NULL
      )
    ''');
  }

  // ---------- Ventes ----------

  // Enregistre la vente et, s'il y en a, le détail de ses articles.
  // Le détail est facultatif : une vente peut n'avoir qu'un montant.
  static Future<void> ajouterVente(Vente vente) async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      final idVente = await txn.insert('ventes', {
        'montant': vente.montant,
        'date': vente.date.toIso8601String(),
      });
      for (final ligne in vente.lignes) {
        await txn.insert('lignes_vente', {
          'vente_id': idVente,
          'article': ligne.article,
          'quantite': ligne.quantite,
          'prix_unitaire': ligne.prixUnitaire,
        });
      }
      // Vente à crédit : ce qui n'est pas payé devient une dette du client.
      // Le motif reprend la liste des articles vendus.
      if (vente.clientId != null && vente.credit > 0) {
        await txn.insert('dettes', {
          'client_id': vente.clientId,
          'motif': vente.lignes.isEmpty ? '' : vente.resume,
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
    final resultat = <Vente>[];

    for (final v in lignesVentes) {
      final id = v['id'] as int;
      final lignes = await db.query(
        'lignes_vente',
        where: 'vente_id = ?',
        whereArgs: [id],
      );
      resultat.add(
        Vente(
          id: id,
          date: DateTime.parse(v['date'] as String),
          montant: v['montant'] as int,
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

  // Supprime les ventes, les dépenses et les dettes. Le catalogue et la liste des clients restent.
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

  // ---------- Catalogue d'articles ----------

  static Future<List<Article>> lireArticles() async {
    final db = await _ouvrir();
    final lignes = await db.query('articles', orderBy: 'nom COLLATE NOCASE');
    return lignes
        .map(
          (l) => Article(
            id: l['id'] as int,
            nom: l['nom'] as String,
            prix: l['prix'] as int,
          ),
        )
        .toList();
  }

  // Ajoute un article, ou le modifie s'il a déjà un id.
  static Future<void> enregistrerArticle(Article article) async {
    final db = await _ouvrir();
    final valeurs = {'nom': article.nom, 'prix': article.prix};
    if (article.id == null) {
      await db.insert('articles', valeurs, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.update(
        'articles',
        valeurs,
        where: 'id = ?',
        whereArgs: [article.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> supprimerArticle(int id) async {
    final db = await _ouvrir();
    await db.delete('articles', where: 'id = ?', whereArgs: [id]);
  }
}
