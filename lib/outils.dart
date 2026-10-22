import 'package:flutter/material.dart';

// Les couleurs de Sakoche (à changer quand le logo sera choisi).
const Color kPrincipal = Color(0xFF0F5132);
const Color kAccent = Color(0xFFF7B500);
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
