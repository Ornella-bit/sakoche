import 'package:flutter/material.dart';

// Les couleurs de Sakoche.
const Color kPrincipal = Color(0xFF0F5132); // vert cauri
const Color kAccent = Color(0xFFF7B500); // jaune soleil
const Color kOcreFonce = Color(0xFF9A6F00); // jaune foncé, pour le nom de l'app
const Color kFond = Color(0xFFF1F7F3);

// Transforme 1250000 en "1 250 000".
String formaterMontant(int nombre) {
  final texte = nombre.toString();
  final resultat = StringBuffer();
  for (int i = 0; i < texte.length; i++) {
    if (i > 0 && (texte.length - i) % 3 == 0) {
      resultat.write(' ');
    }
    resultat.write(texte[i]);
  }
  return resultat.toString();
}

// Dit si deux dates tombent le même jour.
bool memeJour(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

// "Aujourd’hui à 14:05" ou "21/10 à 14:05".
String formaterDateHeure(DateTime date) {
  final heures = date.hour.toString().padLeft(2, '0');
  final minutes = date.minute.toString().padLeft(2, '0');
  if (memeJour(date, DateTime.now())) {
    return 'Aujourd’hui à $heures:$minutes';
  }
  final jour = date.day.toString().padLeft(2, '0');
  final mois = date.month.toString().padLeft(2, '0');
  return '$jour/$mois à $heures:$minutes';
}

// Les noms des jours et des mois en français.
// (weekday vaut 1 pour lundi, 7 pour dimanche ; month vaut 1 pour janvier.)
const List<String> _jours = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];
const List<String> _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

// "jeudi 22 octobre"
String dateDuJour(DateTime date) {
  return '${_jours[date.weekday - 1]} ${date.day} ${_mois[date.month - 1]}';
}

// "J" pour jeudi, "L" pour lundi...
String initialeJour(DateTime date) {
  return _jours[date.weekday - 1][0].toUpperCase();
}
