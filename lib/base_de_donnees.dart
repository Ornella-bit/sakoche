import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 2, // on passe de 1 à 2 : on ajoute le détail des articles
      // Installation toute neuve : on crée les deux tableaux.
      onCreate: (db, version) async {
        await _creerTableVentes(db);
        await _creerTableLignes(db);
      },
      // Téléphone qui avait déjà la version 1 : on ajoute seulement ce qui manque,
      // sans toucher aux ventes déjà enregistrées.
      onUpgrade: (db, ancienneVersion, nouvelleVersion) async {
        if (ancienneVersion < 2) {
          await _creerTableLignes(db);
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

  // Enregistre la vente ET ses articles, ensemble ou pas du tout.
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
    });
  }

  // Lit toutes les ventes (la plus récente d’abord), avec leurs articles.
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
    // Supprime toutes les ventes (et leurs articles).
  static Future<void> toutEffacer() async {
    final db = await _ouvrir();
    await db.transaction((txn) async {
      await txn.delete('lignes_vente');
      await txn.delete('ventes');
    });
  }
}
