import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'base_de_donnees.dart';

// Sauvegarder le carnet dans un fichier, et le restaurer plus tard
// (par exemple sur un nouveau téléphone).
class Sauvegarde {
  // Copie le carnet dans un fichier et ouvre le partage du téléphone :
  // WhatsApp, e-mail, Drive... Le commerçant s'envoie le fichier à lui-même.
  static Future<void> exporter() async {
    final chemin = await BaseDeDonnees.cheminFichier();
    await BaseDeDonnees.fermer(); // on ferme le carnet pour que le fichier soit complet

    final maintenant = DateTime.now();
    final jour = maintenant.day.toString().padLeft(2, '0');
    final mois = maintenant.month.toString().padLeft(2, '0');
    final nom = 'sakoche_sauvegarde_${maintenant.year}-$mois-$jour.db';

    final dossierTemporaire = await getTemporaryDirectory();
    final copie = await File(chemin).copy(join(dossierTemporaire.path, nom));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(copie.path)],
        text: 'Sauvegarde de mon carnet Sakoche du $jour/$mois/${maintenant.year}',
      ),
    );
  }

  // Demande un fichier de sauvegarde et remplace le carnet par son contenu.
  // Renvoie null si l'utilisatrice annule, true si c'est fait.
  // Lance une FormatException si le fichier n'est pas une sauvegarde Sakoche.
  static Future<bool?> restaurer() async {
    final fichier = await FilePicker.pickFile();
    if (fichier == null) return null;

    final octets = await fichier.readAsBytes();

    // Un fichier SQLite commence toujours par ce texte : c'est notre vérification.
    final entete = 'SQLite format 3'.codeUnits;
    if (octets.length < 100) {
      throw const FormatException('Fichier trop petit');
    }
    for (int i = 0; i < entete.length; i++) {
      if (octets[i] != entete[i]) {
        throw const FormatException('Ce n’est pas une sauvegarde');
      }
    }

    final chemin = await BaseDeDonnees.cheminFichier();
    await BaseDeDonnees.fermer();

    // On garde une copie de sécurité du carnet actuel, au cas où.
    final actuel = File(chemin);
    if (await actuel.exists()) {
      await actuel.copy('$chemin.avant_restauration');
    }
    // On supprime les petits fichiers annexes de l'ancien carnet.
    for (final suffixe in ['-journal', '-wal', '-shm']) {
      final annexe = File('$chemin$suffixe');
      if (await annexe.exists()) {
        await annexe.delete();
      }
    }

    await File(chemin).writeAsBytes(octets, flush: true);
    return true;
  }
}
