import 'package:shared_preferences/shared_preferences.dart';

// Les informations de la personne : nom, commerce, téléphone.
// Elles sont rangées avec "shared_preferences" : un petit carnet clé/valeur
// sur le téléphone, parfait pour quelques réglages (pas besoin de tableau SQL).
class Profil {
  final String nom;
  final String commerce;
  final String telephone;

  const Profil({this.nom = '', this.commerce = '', this.telephone = ''});

  static Future<Profil> charger() async {
    final prefs = await SharedPreferences.getInstance();
    return Profil(
      nom: prefs.getString('profil_nom') ?? '',
      commerce: prefs.getString('profil_commerce') ?? '',
      telephone: prefs.getString('profil_telephone') ?? '',
    );
  }

  Future<void> enregistrer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profil_nom', nom);
    await prefs.setString('profil_commerce', commerce);
    await prefs.setString('profil_telephone', telephone);
  }
}
