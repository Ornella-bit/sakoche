import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_de_donnees.dart';
import 'client.dart';
import 'clients_page.dart';
import 'outils.dart';
import 'vente.dart';

// Enregistrer une vente = un montant. Et, si on veut, une note libre
// pour se rappeler "pour quoi" (pommes, oignons, couture...).
class NouvelleVentePage extends StatefulWidget {
  const NouvelleVentePage({super.key});

  @override
  State<NouvelleVentePage> createState() => _NouvelleVentePageState();
}

class _NouvelleVentePageState extends State<NouvelleVentePage> {
  final TextEditingController _montantController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _payeController = TextEditingController(text: '0');

  List<String> _notesRecentes = []; // les dernières notes, proposées comme raccourcis
  List<Client> _clients = [];
  bool _credit = false;
  Client? _clientChoisi;

  int get _total => int.tryParse(_montantController.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _chargerNotes();
    _chargerClients();
  }

  Future<void> _chargerNotes() async {
    final notes = await BaseDeDonnees.lireNotesRecentes();
    if (!mounted) return;
    setState(() {
      _notesRecentes = notes;
    });
  }

  Future<void> _chargerClients() async {
    final clients = await BaseDeDonnees.lireClients();
    if (!mounted) return;
    setState(() {
      _clients = clients;
    });
  }

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  // Une feuille qui propose la liste des clients, avec "Nouveau client" en premier.
  Future<void> _choisirClient() async {
    final choix = await showModalBottomSheet<Client>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_add_alt),
                title: const Text('Nouveau client'),
                onTap: () async {
                  final nouveau = await demanderNouveauClient(sheetContext);
                  if (nouveau != null && sheetContext.mounted) {
                    Navigator.pop(sheetContext, nouveau);
                  }
                },
              ),
              for (final client in _clients)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(client.nom),
                  subtitle: client.dette > 0
                      ? Text('Doit déjà ${formaterMontant(client.dette)} FCFA')
                      : null,
                  onTap: () => Navigator.pop(sheetContext, client),
                ),
            ],
          ),
        );
      },
    );
    if (choix == null) return;
    await _chargerClients();
    if (!mounted) return;
    setState(() {
      _clientChoisi = choix;
    });
  }

  Future<void> _enregistrer() async {
    final total = _total;
    if (total <= 0) {
      _message('Entre le montant de la vente');
      return;
    }

    // Si la vente est à crédit : ce qui n'est pas payé tout de suite
    // devient une dette du client.
    int credit = 0;
    int? clientId;
    if (_credit) {
      if (_clientChoisi == null) {
        _message('Choisis le client qui prend à crédit');
        return;
      }
      final paye = int.tryParse(_payeController.text.trim()) ?? 0;
      if (paye > total) {
        _message('Le montant payé dépasse le total de la vente');
        return;
      }
      credit = total - paye;
      clientId = _clientChoisi!.id;
    }

    final vente = Vente(
      date: DateTime.now(),
      lignes: const [],
      montant: total,
      note: _noteController.text.trim(),
      clientId: clientId,
      credit: credit,
    );
    await BaseDeDonnees.ajouterVente(vente);
    if (!mounted) return;

    // On revient à la page précédente en disant "c'est enregistré" (true).
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _montantController.dispose();
    _noteController.dispose();
    _payeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paye = int.tryParse(_payeController.text.trim()) ?? 0;
    final reste = _total - paye < 0 ? 0 : _total - paye;
    final total = _total;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // L'essentiel : le montant. Le clavier s'ouvre tout de suite.
          TextField(
            controller: _montantController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'Montant de la vente (FCFA)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Un texte libre, juste pour se souvenir. Aucune liste à préparer.
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Pour quoi ? (facultatif)',
              hintText: 'Ex : pommes, oignons, couture...',
              border: OutlineInputBorder(),
            ),
          ),

          // Les dernières notes déjà utilisées : un clic et c'est rempli.
          if (_notesRecentes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final note in _notesRecentes)
                  ActionChip(
                    label: Text(note),
                    onPressed: () {
                      setState(() {
                        _noteController.text = note;
                      });
                    },
                  ),
              ],
            ),
          ],

          // La vente à crédit.
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vente à crédit'),
            subtitle: const Text('Le client paie plus tard (tout ou une partie)'),
            value: _credit,
            onChanged: (valeur) {
              setState(() {
                _credit = valeur;
              });
            },
          ),
          if (_credit) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _choisirClient,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.person_outline),
              label: Text(_clientChoisi?.nom ?? 'Choisir un client'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _payeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Montant payé tout de suite (FCFA)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reste à payer : ${formaterMontant(reste)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFB3261E)),
            ),
          ],
        ],
      ),

      // Un seul gros bouton, qui rappelle le montant.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _enregistrer,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: Text(
              total > 0
                  ? 'Enregistrer ${formaterMontant(total)} FCFA'
                  : 'Enregistrer la vente',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
