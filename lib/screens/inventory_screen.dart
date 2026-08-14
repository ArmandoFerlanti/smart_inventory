import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _supabase = Supabase.instance.client;

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '0');
    final minController = TextEditingController(text: '5');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? errorMessage;

          Future<void> save() async {
            final quantity = int.tryParse(qtyController.text);
            final minThreshold = int.tryParse(minController.text);

            if (nameController.text.trim().isEmpty) {
              dialogSetState(() => errorMessage = 'Inserisci un nome per l\'oggetto.');
              return;
            }
            if (quantity == null) {
              dialogSetState(() => errorMessage = 'La quantità non è un numero valido.');
              return;
            }
            if (minThreshold == null) {
              dialogSetState(() => errorMessage = 'La soglia minima non è un numero valido.');
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _supabase.from('inventory').insert({
                'item_name': nameController.text.trim(),
                'quantity': quantity,
                'min_threshold': minThreshold,
              });
              if (mounted) {
                Navigator.pop(this.context);
                setState(() {});
              }
            } catch (e) {
              debugPrint('Errore salvataggio inventario: $e');
              dialogSetState(() {
                isSaving = false;
                errorMessage = 'Errore durante il salvataggio: $e';
              });
            }
          }

          return AlertDialog(
            title: const Text('Aggiungi Articolo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome Oggetto'),
                ),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantità Iniziale'),
                ),
                TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Soglia Minima Allarme'),
                ),
                if (errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateQuantity(String id, int currentQty, int delta) async {
    final newQty = currentQty + delta;
    if (newQty < 0) return;
    try {
      await _supabase.from('inventory').update({'quantity': newQty}).eq('id', id);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Errore aggiornamento quantità: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore aggiornamento quantità: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _supabase.from('inventory').select().order('created_at'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Errore nel caricamento: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Nessun articolo presente in inventario.'));
          }

          final items = snapshot.data!;

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isLow = (item['quantity'] as int) <= (item['min_threshold'] as int);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(
                    isLow ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                    color: isLow ? Colors.orange : Colors.green,
                  ),
                  title: Text(
                    item['item_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Soglia minima: ${item['min_threshold']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _updateQuantity(item['id'], item['quantity'], -1),
                      ),
                      Text(
                        '${item['quantity']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isLow ? Colors.red : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _updateQuantity(item['id'], item['quantity'], 1),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}