import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'article.dart';
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
      version: 4, // version 4 : on ajoute les dépenses
      onCreate: (db, version) async {
        await _creerTableVentes(db);
        await _creerTableLignes(db);
        await _creerTableArticles(db);
        await _creerTableDepenses(db);
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

  // Supprime toutes les ventes et toutes les dépenses. Le catalogue reste.
  static Future<void> toutEffacer() async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      await txn.delete('lignes_vente');
      await txn.delete('ventes');
      await txn.delete('depenses');
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
