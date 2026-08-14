import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isExporting = false;

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
              dialogSetState(
                () => errorMessage = 'Inserisci un nome per l\'oggetto.',
              );
              return;
            }
            if (quantity == null) {
              dialogSetState(
                () => errorMessage = 'La quantità non è un numero valido.',
              );
              return;
            }
            if (minThreshold == null) {
              dialogSetState(
                () => errorMessage = 'La soglia minima non è un numero valido.',
              );
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
                  decoration: const InputDecoration(
                    labelText: 'Quantità Iniziale',
                  ),
                ),
                TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Soglia Minima Allarme',
                  ),
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
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
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
      await _supabase
          .from('inventory')
          .update({'quantity': newQty})
          .eq('id', id);
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

  bool _isLow(Map<String, dynamic> item) =>
      (item['quantity'] as int) <= (item['min_threshold'] as int);

  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget _pdfCell(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text));

  Future<Uint8List> _generatePdf(List<Map<String, dynamic>> items) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final lowItems = items.where(_isLow).length;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Inventario Sede',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generato il $dateStr',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Totale articoli: ${items.length}  ·  Sotto soglia: $lowItems',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber} di ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
            },
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('Nome'),
                  _pdfHeaderCell('Quantità'),
                  _pdfHeaderCell('Soglia Min.'),
                  _pdfHeaderCell('Stato'),
                ],
              ),
              for (final item in items)
                pw.TableRow(
                  children: [
                    _pdfCell(item['item_name'] as String? ?? ''),
                    _pdfCell('${item['quantity']}'),
                    _pdfCell('${item['min_threshold']}'),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        _isLow(item) ? 'DA COMPRARE' : 'OK',
                        style: pw.TextStyle(
                          color: _isLow(item)
                              ? PdfColors.red700
                              : PdfColors.green700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      final items = await _supabase
          .from('inventory')
          .select()
          .order('created_at');
      final bytes = await _generatePdf(items);
      if (!mounted) return;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'inventario_$dateStr.pdf',
      );
    } catch (e) {
      debugPrint('Errore export PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Errore export PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteItem(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina articolo'),
        content: Text(
          'Vuoi eliminare definitivamente "$name" dall\'inventario?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _supabase.from('inventory').delete().eq('id', id);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Errore eliminazione articolo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore eliminazione articolo: $e')),
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
            return const Center(
              child: Text('Nessun articolo presente in inventario.'),
            );
          }

          final items = snapshot.data!;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _exportPdf,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _isExporting ? 'Generazione...' : 'Esporta PDF',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isLow = _isLow(item);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Icon(
                          isLow
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined,
                          color: isLow ? Colors.orange : Colors.green,
                        ),
                        title: Text(
                          item['item_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Soglia minima: ${item['min_threshold']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _updateQuantity(
                                item['id'],
                                item['quantity'],
                                -1,
                              ),
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
                              onPressed: () => _updateQuantity(
                                item['id'],
                                item['quantity'],
                                1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Elimina',
                              onPressed: () =>
                                  _deleteItem(item['id'], item['item_name']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
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
