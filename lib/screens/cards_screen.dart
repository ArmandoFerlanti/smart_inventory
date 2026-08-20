import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isExporting = false;

  static const String _euroSign = '\u20AC';

  String _formatCurrency(num value) {
    final formatter =
        NumberFormat.currency(locale: 'it_IT', symbol: '$_euroSign ');
    return formatter.format(value);
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // ===========================
  // ADD / EDIT DIALOG
  // ===========================

  void _showAddCardDialog() {
    final numberController = TextEditingController();
    final assignedController = TextEditingController();
    double selectedValue = 10;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? errorMessage;

          Future<void> save() async {
            final cardNumber = int.tryParse(numberController.text.trim());

            if (cardNumber == null) {
              dialogSetState(
                () => errorMessage = 'Inserisci un numero valido.',
              );
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _supabase.from('cards').insert({
                'card_number': cardNumber,
                'assigned_to': assignedController.text.trim(),
                'value': selectedValue,
              });
              if (mounted) {
                Navigator.pop(this.context);
                setState(() {});
              }
            } catch (e) {
              debugPrint('Errore salvataggio scheda: $e');
              dialogSetState(() {
                isSaving = false;
                if (e.toString().contains('duplicate key') ||
                    e.toString().contains('unique constraint')) {
                  errorMessage = 'Esiste già una scheda con questo numero.';
                } else {
                  errorMessage = 'Errore durante il salvataggio: $e';
                }
              });
            }
          }

          return AlertDialog(
            title: const Text('Aggiungi Scheda'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Numero Scheda'),
                ),
                TextField(
                  controller: assignedController,
                  decoration: const InputDecoration(
                    labelText: 'Assegnata a',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: selectedValue,
                  decoration: const InputDecoration(
                    labelText: 'Valore',
                  ),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 €')),
                    DropdownMenuItem(value: 20, child: Text('20 €')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      dialogSetState(() => selectedValue = val);
                    }
                  },
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

  void _showEditCardDialog(Map<String, dynamic> card) {
    final numberController = TextEditingController(
      text: '${card['card_number']}',
    );
    final assignedController = TextEditingController(
      text: card['assigned_to'] ?? '',
    );
    double selectedValue = (card['value'] as num).toDouble();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? errorMessage;

          Future<void> save() async {
            final cardNumber = int.tryParse(numberController.text.trim());

            if (cardNumber == null) {
              dialogSetState(
                () => errorMessage = 'Inserisci un numero valido.',
              );
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _supabase.from('cards').update({
                'card_number': cardNumber,
                'assigned_to': assignedController.text.trim(),
                'value': selectedValue,
              }).eq('id', card['id']);
              if (mounted) {
                Navigator.pop(this.context);
                setState(() {});
              }
            } catch (e) {
              debugPrint('Errore aggiornamento scheda: $e');
              dialogSetState(() {
                isSaving = false;
                if (e.toString().contains('duplicate key') ||
                    e.toString().contains('unique constraint')) {
                  errorMessage = 'Esiste già una scheda con questo numero.';
                } else {
                  errorMessage = 'Errore durante il salvataggio: $e';
                }
              });
            }
          }

          return AlertDialog(
            title: const Text('Modifica Scheda'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Numero Scheda'),
                ),
                TextField(
                  controller: assignedController,
                  decoration: const InputDecoration(
                    labelText: 'Assegnata a',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: selectedValue,
                  decoration: const InputDecoration(
                    labelText: 'Valore',
                  ),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 €')),
                    DropdownMenuItem(value: 20, child: Text('20 €')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      dialogSetState(() => selectedValue = val);
                    }
                  },
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

  // ===========================
  // DELETE
  // ===========================

  Future<void> _deleteCard(String id, int cardNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina scheda'),
        content: Text(
          'Vuoi eliminare definitivamente la scheda n. $cardNumber?',
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
      await _supabase.from('cards').delete().eq('id', id);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Errore eliminazione scheda: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore eliminazione scheda: $e')),
        );
      }
    }
  }

  // ===========================
  // PDF
  // ===========================

  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget _pdfCell(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text));

  Future<Uint8List> _generatePdf(List<Map<String, dynamic>> cards) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final pdf = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final fontDataBold = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontDataBold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Schede Tessere Bar',
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
              'Totale schede: ${cards.length}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
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
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('N.'),
                  _pdfHeaderCell('Assegnata a'),
                  _pdfHeaderCell('Valore'),
                  _pdfHeaderCell('Data Creazione'),
                ],
              ),
              for (final card in cards)
                pw.TableRow(
                  children: [
                    _pdfCell('${card['card_number']}'),
                    _pdfCell(card['assigned_to'] as String? ?? ''),
                    _pdfCell(_formatCurrency(card['value'] as num)),
                    _pdfCell(
                      _formatDate(
                        DateTime.parse(card['created_at'] as String),
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
          .from('cards')
          .select()
          .order('card_number');
      final bytes = await _generatePdf(items);
      if (!mounted) return;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'schede_$dateStr.pdf',
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

  // ===========================
  // BUILD
  // ===========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _supabase.from('cards').select().order('card_number'),
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
              child: Text('Nessuna scheda presente.'),
            );
          }

          final cards = snapshot.data!;

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
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final value = card['value'] as num;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.credit_card,
                          color: value == 20 ? Colors.amber : Colors.blue,
                        ),
                        title: Text(
                          'Scheda n. ${card['card_number']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${card['assigned_to'] ?? 'Non assegnata'}  ·  ${_formatCurrency(value)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Modifica',
                              onPressed: () => _showEditCardDialog(card),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Elimina',
                              onPressed: () => _deleteCard(
                                card['id'],
                                card['card_number'],
                              ),
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
        onPressed: _showAddCardDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
