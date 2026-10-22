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
      version: 5, // version 5 : on ajoute les clients et les dettes
      onCreate: (db, version) async {
        await _creerTableVentes(db);
        await _creerTableLignes(db);
        await _creerTableArticles(db);
        await _creerTableDepenses(db);
        await _creerTablesClients(db);
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
          await _creerTablesClients(db);
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

  // Deux tableaux : les clients, et leur "compte" (dettes et remboursements).
  static Future<void> _creerTablesClients(Database db) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE COLLATE NOCASE,
        telephone TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE operations_client (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        montant INTEGER NOT NULL,
        date TEXT NOT NULL
      )
    ''');
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

  // Enregistre la vente ET ses articles. Chaque article vendu est aussi
  // mémorisé dans le catalogue (avec son prix), donc le catalogue se remplit tout seul.
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
        await txn.insert(
          'articles',
          {'nom': ligne.article, 'prix': ligne.prixUnitaire},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      // Vente à crédit : on note ce que le client doit sur son compte.
      if (vente.clientId != null && vente.credit > 0) {
        await txn.insert('operations_client', {
          'client_id': vente.clientId,
          'type': typeCredit,
          'montant': vente.credit,
          'date': vente.date.toIso8601String(),
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
      await txn.delete('operations_client');
    });
  }

  // ---------- Clients et dettes ----------

  // Lit les clients avec ce que chacun doit : la somme de ses dettes
  // moins la somme de ses remboursements (calculée par la base elle-même).
  static Future<List<Client>> lireClients() async {
    final db = await _ouvrir();
    final lignes = await db.rawQuery('''
      SELECT c.id, c.nom, c.telephone,
        COALESCE(SUM(CASE WHEN o.type = 'credit' THEN o.montant
                          WHEN o.type = 'remboursement' THEN -o.montant END), 0) AS dette
      FROM clients c
      LEFT JOIN operations_client o ON o.client_id = c.id
      GROUP BY c.id
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
      await txn.delete('operations_client', where: 'client_id = ?', whereArgs: [id]);
      await txn.delete('clients', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> ajouterOperation(OperationClient operation) async {
    final db = await _ouvrir();
    await db.insert('operations_client', {
      'client_id': operation.clientId,
      'type': operation.type,
      'montant': operation.montant,
      'date': operation.date.toIso8601String(),
    });
  }

  static List<OperationClient> _versOperations(List<Map<String, Object?>> lignes) {
    return lignes
        .map(
          (l) => OperationClient(
            id: l['id'] as int,
            clientId: l['client_id'] as int,
            type: l['type'] as String,
            montant: l['montant'] as int,
            date: DateTime.parse(l['date'] as String),
          ),
        )
        .toList();
  }

  // L'historique d'un seul client.
  static Future<List<OperationClient>> lireOperations(int clientId) async {
    final db = await _ouvrir();
    final lignes = await db.query(
      'operations_client',
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'date DESC',
    );
    return _versOperations(lignes);
  }

  // Toutes les opérations (pour les chiffres de l'accueil).
  static Future<List<OperationClient>> lireToutesOperations() async {
    final db = await _ouvrir();
    return _versOperations(await db.query('operations_client'));
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
