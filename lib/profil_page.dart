import 'package:flutter/material.dart';

import 'profil.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _commerceController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  // On remplit les champs avec ce qui a déjà été enregistré.
  Future<void> _charger() async {
    final profil = await Profil.charger();
    if (!mounted) return;
    setState(() {
      _nomController.text = profil.nom;
      _commerceController.text = profil.commerce;
      _telephoneController.text = profil.telephone;
    });
  }

  Future<void> _enregistrer() async {
    final profil = Profil(
      nom: _nomController.text.trim(),
      commerce: _commerceController.text.trim(),
      telephone: _telephoneController.text.trim(),
    );
    await profil.enregistrer();
    if (!mounted) return;
    Navigator.pop(context, true); // true = "j'ai modifié le profil"
  }

  @override
  void dispose() {
    _nomController.dispose();
    _commerceController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Mon nom',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commerceController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nom de mon commerce',
              hintText: 'Ex : Boutique Espoir',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telephoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _enregistrer,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
