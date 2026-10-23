import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'base_de_donnees.dart';
import 'client.dart';
import 'depenses_page.dart';
import 'outils.dart';

// Ce que l'utilisatrice a saisi dans la boîte "dette".
class _SaisieDette {
  final String motif;
  final int montant;
  final DateTime? date; // null = pas de date choisie (on prendra aujourd'hui)

  const _SaisieDette({required this.motif, required this.montant, required this.date});
}

// Ce que l'utilisatrice a saisi dans la boîte "remboursement".
class _SaisieRemboursement {
  final int montant;
  final DateTime date;

  const _SaisieRemboursement({required this.montant, required this.date});
}

// Le compte d'un client : ce qu'il doit, et la liste de ses dettes.
class ClientPage extends StatefulWidget {
  final Client client;
  final Future<void> Function() onChange;

  const ClientPage({super.key, required this.client, required this.onChange});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  List<Dette> _dettes = [];

  // Ce que le client doit en tout : la somme de ce qui reste sur chaque dette.
  int get _total {
    int somme = 0;
    for (final dette in _dettes) {
      somme += dette.restant;
    }
    return somme;
  }

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final dettes = await BaseDeDonnees.lireDettes(widget.client.id!);
    if (!mounted) return;
    setState(() {
      _dettes = dettes;
    });
  }

  // Une date choisie dans le calendrier n'a pas d'heure : on lui ajoute l'heure actuelle.
  DateTime _avecHeure(DateTime? date) {
    final maintenant = DateTime.now();
    if (date == null) return maintenant;
    return DateTime(date.year, date.month, date.day, maintenant.hour, maintenant.minute);
  }

  Future<void> _nouvelleDette() async {
    final saisie = await showDialog<_SaisieDette>(
      context: context,
      builder: (_) => const _BoiteDette(),
    );
    if (saisie == null) return;

    await BaseDeDonnees.ajouterDette(
      Dette(
        clientId: widget.client.id!,
        motif: saisie.motif,
        montant: saisie.montant,
        date: _avecHeure(saisie.date),
      ),
    );
    await _charger();
    await widget.onChange();
  }

  Future<void> _modifier(Dette dette) async {
    final saisie = await showDialog<_SaisieDette>(
      context: context,
      builder: (_) => _BoiteDette(existante: dette),
    );
    if (saisie == null) return;

    // Si le jour n'a pas changé, on garde la date (et l'heure) d'origine.
    final DateTime date;
    if (saisie.date == null) {
      date = DateTime.now();
    } else if (memeJour(saisie.date!, dette.date)) {
      date = dette.date;
    } else {
      date = _avecHeure(saisie.date);
    }

    await BaseDeDonnees.modifierDette(
      id: dette.id!,
      motif: saisie.motif,
      montant: saisie.montant,
      date: date,
    );
    await _charger();
    await widget.onChange();
  }

  Future<void> _rembourser(Dette dette) async {
    final saisie = await showDialog<_SaisieRemboursement>(
      context: context,
      builder: (_) => _BoiteRemboursement(restant: dette.restant),
    );
    if (saisie == null) return;

    await BaseDeDonnees.ajouterRemboursement(
      Remboursement(
        detteId: dette.id!,
        montant: saisie.montant,
        date: _avecHeure(saisie.date),
      ),
    );
    await _charger();
    await widget.onChange();
  }

  Future<void> _supprimerDette(Dette dette) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer cette dette ?'),
          content: Text(
            'La dette de ${formaterMontant(dette.montant)} FCFA et ses remboursements seront supprimés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirme != true) return;

    await BaseDeDonnees.supprimerDette(dette.id!);
    await _charger();
    await widget.onChange();
  }

  Future<void> _supprimerClient() async {
    if (_total > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce client doit encore ${formaterMontant(_total)} FCFA. Il ne peut pas être supprimé.',
          ),
        ),
      );
      return;
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce client ?'),
          content: Text('« ${widget.client.nom} » et son historique seront supprimés.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirme != true) return;

    await BaseDeDonnees.supprimerClient(widget.client.id!);
    await widget.onChange();
    if (!mounted) return;
    Navigator.pop(context);
  }

  // La carte d'une dette, avec ses trois points.
  Widget _carteDette(Dette dette) {
    final titre = dette.motif.isNotEmpty
        ? dette.motif
        : (dette.venteId != null ? 'Vente à crédit' : 'Dette');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F5132), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    titre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formaterDate(dette.date),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B63)),
                ),
                const SizedBox(height: 8),
                Text('Montant : ${formaterMontant(dette.montant)} FCFA'),
                // Chaque remboursement de cette dette.
                for (final r in dette.remboursements)
                  Text(
                    'Remboursé le ${formaterDate(r.date)} : − ${formaterMontant(r.montant)} FCFA',
                    style: const TextStyle(fontSize: 12, color: kPrincipal),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (choix) {
                  if (choix == 'rembourser') _rembourser(dette);
                  if (choix == 'supprimer') _supprimerDette(dette);
                  if (choix == 'modifier') _modifier(dette);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rembourser',
                    enabled: !dette.estSoldee,
                    child: const Text('Rembourser'),
                  ),
                  const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                  const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: dette.estSoldee
                    ? const Text(
                        'Payée',
                        style: TextStyle(fontWeight: FontWeight.bold, color: kPrincipal),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Reste à payer',
                            style: TextStyle(fontSize: 11, color: Color(0xFF5B6B63)),
                          ),
                          Text(
                            '${formaterMontant(dette.restant)} FCFA',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: kRouge),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final total = _total;

    return Scaffold(
      appBar: AppBar(
        title: Text(client.nom),
        actions: [
          IconButton(
            tooltip: 'Supprimer le client',
            icon: const Icon(Icons.delete_outline),
            onPressed: _supprimerClient,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouvelleDette,
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle dette'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          // Ce que le client doit en tout.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(color: Color(0x1A0F5132), blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (client.telephone.isNotEmpty) ...[
                  Text(client.telephone, style: const TextStyle(color: Color(0xFF5B6B63))),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Dette actuelle',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6B63)),
                ),
                Text(
                  total > 0 ? '${formaterMontant(total)} FCFA' : 'À jour',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: total > 0 ? kRouge : kPrincipal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Dettes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_dettes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Aucune dette pour le moment.')),
            ),
          for (final dette in _dettes) _carteDette(dette),
        ],
      ),
    );
  }
}

// La boîte pour créer une dette ou la modifier : motif, montant, date.
class _BoiteDette extends StatefulWidget {
  final Dette? existante; // null = nouvelle dette

  const _BoiteDette({this.existante});

  @override
  State<_BoiteDette> createState() => _BoiteDetteState();
}

class _BoiteDetteState extends State<_BoiteDette> {
  late final TextEditingController _motifController;
  late final TextEditingController _montantController;
  DateTime? _date;
  String? _erreurMontant;

  @override
  void initState() {
    super.initState();
    final existante = widget.existante;
    _motifController = TextEditingController(text: existante?.motif ?? '');
    _montantController = TextEditingController(
      text: existante == null ? '' : existante.montant.toString(),
    );
    _date = existante?.date;
  }

  @override
  void dispose() {
    _motifController.dispose();
    _montantController.dispose();
    super.dispose();
  }

  // Ouvre le calendrier.
  Future<void> _choisirDate() async {
    final aujourdhui = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date ?? aujourdhui,
      firstDate: DateTime(2000),
      lastDate: aujourdhui,
    );
    if (choisie != null) {
      setState(() {
        _date = choisie;
      });
    }
  }

  void _enregistrer() {
    final montant = int.tryParse(_montantController.text.trim());
    if (montant == null || montant <= 0) {
      setState(() {
        _erreurMontant = 'Entre un montant valide';
      });
      return;
    }
    // En modifiant, le montant ne peut pas être plus petit que ce qui est déjà remboursé.
    final dejaRembourse = widget.existante?.rembourse ?? 0;
    if (montant < dejaRembourse) {
      setState(() {
        _erreurMontant = 'Au moins ${formaterMontant(dejaRembourse)} FCFA (déjà remboursé)';
      });
      return;
    }
    Navigator.pop(
      context,
      _SaisieDette(
        motif: _motifController.text.trim(),
        montant: montant,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existante == null ? 'Nouvelle dette' : 'Modifier la dette'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _motifController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
                hintText: 'Ex : 2 sacs de riz',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Montant (FCFA)',
                errorText: _erreurMontant,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Toucher cette case ouvre le calendrier.
            InkWell(
              onTap: _choisirDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date (facultatif)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _date == null
                      ? const Icon(Icons.calendar_today_outlined)
                      : IconButton(
                          tooltip: 'Effacer la date',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _date = null;
                            });
                          },
                        ),
                ),
                child: Text(
                  _date == null ? 'Aujourd’hui par défaut' : formaterDate(_date!),
                  style: TextStyle(color: _date == null ? const Color(0xFF5B6B63) : null),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _enregistrer,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// La boîte pour rembourser une dette : montant et date.
class _BoiteRemboursement extends StatefulWidget {
  final int restant; // ce qui reste à payer sur la dette

  const _BoiteRemboursement({required this.restant});

  @override
  State<_BoiteRemboursement> createState() => _BoiteRemboursementState();
}

class _BoiteRemboursementState extends State<_BoiteRemboursement> {
  final TextEditingController _montantController = TextEditingController();
  DateTime _date = DateTime.now(); // la date du jour, modifiable
  String? _erreurMontant;

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final aujourdhui = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: aujourdhui,
    );
    if (choisie != null) {
      setState(() {
        _date = choisie;
      });
    }
  }

  void _enregistrer() {
    final montant = int.tryParse(_montantController.text.trim());
    if (montant == null || montant <= 0) {
      setState(() {
        _erreurMontant = 'Entre un montant valide';
      });
      return;
    }
    if (montant > widget.restant) {
      setState(() {
        _erreurMontant = 'Plus que le reste à payer (${formaterMontant(widget.restant)} FCFA)';
      });
      return;
    }
    Navigator.pop(context, _SaisieRemboursement(montant: montant, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rembourser'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reste à payer : ${formaterMontant(widget.restant)} FCFA',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _montantController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Montant remboursé (FCFA)',
                errorText: _erreurMontant,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _choisirDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(formaterDate(_date)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _enregistrer,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
