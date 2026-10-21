import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Les couleurs de Sakoche : bleu indigo (comme les pagnes teintés)
// et ocre (comme l'or des cauris).
const Color kIndigo = Color(0xFF1F3A5F);
const Color kOcre = Color(0xFFE0A526);
const Color kFond = Color(0xFFF3F6F9);

// Point de départ de toute application Flutter.
void main() {
  runApp(const SakocheApp());
}

// L'application elle-même : son nom, son thème (couleurs) et sa première page.
class SakocheApp extends StatelessWidget {
  const SakocheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sakoche',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kIndigo),
        scaffoldBackgroundColor: kFond,
        useMaterial3: true,
      ),
      home: const AccueilPage(),
    );
  }
}

// Une vente = un montant + le moment où elle a été faite.
class Vente {
  final int montant;
  final DateTime date;

  Vente(this.montant, this.date);
}

// Transforme 1250000 en "1 250 000" pour que les grands nombres restent lisibles.
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

// Transforme une date en "14:05".
String formaterHeure(DateTime date) {
  final heures = date.hour.toString().padLeft(2, '0');
  final minutes = date.minute.toString().padLeft(2, '0');
  return '$heures:$minutes';
}

// La page d'accueil. "Stateful" = son contenu change (la liste des ventes grandit).
class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> {
  // Récupère ce que l'utilisatrice tape dans le champ de saisie.
  final TextEditingController _montantController = TextEditingController();

  // La liste des ventes (pour l'instant, gardée seulement en mémoire).
  final List<Vente> _ventes = [];

  // Le total est recalculé à chaque fois en additionnant toutes les ventes.
  int get _total {
    int somme = 0;
    for (final vente in _ventes) {
      somme += vente.montant;
    }
    return somme;
  }

  void _ajouterVente() {
    final montant = int.tryParse(_montantController.text.trim());

    // Si le champ est vide ou le montant invalide, on prévient et on s'arrête.
    if (montant == null || montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre un montant valide, par exemple 2500')),
      );
      return;
    }

    // setState dit à Flutter : "les données ont changé, redessine l'écran".
    setState(() {
      _ventes.insert(0, Vente(montant, DateTime.now()));
    });
    _montantController.clear();
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Bandeau du haut : le total des ventes, bien visible.
          Container(
            width: double.infinity,
            color: kIndigo,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sakoche',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Total des ventes',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formaterMontant(_total)} FCFA',
                    style: const TextStyle(
                      color: kOcre,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zone de saisie : le montant et le bouton.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _montantController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Montant de la vente (FCFA)',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _ajouterVente(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _ajouterVente,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter la vente'),
                ),
              ],
            ),
          ),

          // La liste des ventes, la plus récente en premier.
          Expanded(
            child: _ventes.isEmpty
                ? const Center(
                    child: Text('Aucune vente pour le moment. Ajoute la première !'),
                  )
                : ListView.builder(
                    itemCount: _ventes.length,
                    itemBuilder: (context, index) {
                      final vente = _ventes[index];
                      return ListTile(
                        leading: const Icon(Icons.payments_outlined, color: kIndigo),
                        title: Text(
                          '${formaterMontant(vente.montant)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('Vente à ${formaterHeure(vente.date)}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}