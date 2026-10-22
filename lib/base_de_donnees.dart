import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'vente.dart';

// Tout ce qui concerne la base de données est rangé ici,
// pour que le reste de l'application n'ait pas à s'en occuper.
class BaseDeDonnees {
  static Database? _base;

  // Ouvre la base (et la crée la toute première fois).
  static Future<Database> _ouvrir() async {
    if (_base != null) {
      return _base!;
    }

    final dossier = await getDatabasesPath(); // dossier réservé aux bases, sur le téléphone
    final chemin = join(dossier, 'sakoche.db');

    _base = await openDatabase(
      chemin,
      version: 1,
      onCreate: (db, version) async {
        // Exécuté une seule fois : on crée le tableau "ventes".
        await db.execute('''
          CREATE TABLE ventes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            montant INTEGER NOT NULL,
            date TEXT NOT NULL
          )
        ''');
      },
    );
    return _base!;
  }

  // Ajoute une vente dans le tableau.
  static Future<int> ajouterVente(Vente vente) async {
    final db = await _ouvrir();
    return db.insert('ventes', vente.toMap());
  }

  // Lit toutes les ventes, la plus récente en premier.
  static Future<List<Vente>> lireVentes() async {
    final db = await _ouvrir();
    final lignes = await db.query('ventes', orderBy: 'date DESC');
    return lignes.map((ligne) => Vente.fromMap(ligne)).toList();
  }
}
