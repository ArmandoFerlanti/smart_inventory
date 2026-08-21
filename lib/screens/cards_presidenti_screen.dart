import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CardsPresidentiScreen extends StatefulWidget {
  const CardsPresidentiScreen({super.key});

  @override
  State<CardsPresidentiScreen> createState() => _CardsPresidentiScreenState();
}

class _CardsPresidentiScreenState extends State<CardsPresidentiScreen> {
  final _supabase = Supabase.instance.client;
  bool _isExporting = false;

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _formatDateDb(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  String _formatOptionalDate(dynamic value) {
    final date = _parseDate(value);
    return date != null ? _formatDate(date) : '-';
  }

  // ===========================
  // DATE FIELD
  // ===========================

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPicked,
  }) =>
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onPicked(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          ),
          child: Text(
            value != null ? _formatDate(value) : '',
            style: TextStyle(color: value != null ? null : Colors.grey),
          ),
        ),
      );

  // ===========================
  // ADD / EDIT DIALOG
  // ===========================

  void _showAddCardDialog() {
    final assignedController = TextEditingController();
    DateTime? releasedOn;
    DateTime? expiresOn;
    var isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Future<void> save() async {
            final assignedTo = assignedController.text.trim();

            if (assignedTo.isEmpty) {
              dialogSetState(
                () => errorMessage = 'Inserisci il nome della persona.',
              );
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _supabase.from('cards_presidenti').insert({
                'assigned_to': assignedTo,
                'released_on':
                    releasedOn != null ? _formatDateDb(releasedOn!) : null,
                'expires_on':
                    expiresOn != null ? _formatDateDb(expiresOn!) : null,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            } catch (e) {
              debugPrint('Errore salvataggio scheda presidente: $e');
              dialogSetState(() {
                isSaving = false;
                errorMessage = 'Errore durante il salvataggio: $e';
              });
            }
          }

          return AlertDialog(
            title: const Text('Aggiungi Scheda Presidente'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: assignedController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Assegnata a'),
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Rilasciata il',
                  value: releasedOn,
                  onPicked: (date) =>
                      dialogSetState(() => releasedOn = date),
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Scadenza',
                  value: expiresOn,
                  onPicked: (date) => dialogSetState(() => expiresOn = date),
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
    final assignedController = TextEditingController(
      text: card['assigned_to'] ?? '',
    );
    DateTime? releasedOn = _parseDate(card['released_on']);
    DateTime? expiresOn = _parseDate(card['expires_on']);
    var isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Future<void> save() async {
            final assignedTo = assignedController.text.trim();

            if (assignedTo.isEmpty) {
              dialogSetState(
                () => errorMessage = 'Inserisci il nome della persona.',
              );
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _supabase.from('cards_presidenti').update({
                'assigned_to': assignedTo,
                'released_on':
                    releasedOn != null ? _formatDateDb(releasedOn!) : null,
                'expires_on':
                    expiresOn != null ? _formatDateDb(expiresOn!) : null,
              }).eq('id', card['id']);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            } catch (e) {
              debugPrint('Errore aggiornamento scheda presidente: $e');
              dialogSetState(() {
                isSaving = false;
                errorMessage = 'Errore durante il salvataggio: $e';
              });
            }
          }

          return AlertDialog(
            title: const Text('Modifica Scheda Presidente'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: assignedController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Assegnata a'),
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Rilasciata il',
                  value: releasedOn,
                  onPicked: (date) =>
                      dialogSetState(() => releasedOn = date),
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Scadenza',
                  value: expiresOn,
                  onPicked: (date) => dialogSetState(() => expiresOn = date),
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

  Future<void> _deleteCard(String id, String assignedTo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina scheda'),
        content: Text(
          'Vuoi eliminare definitivamente la scheda di $assignedTo?',
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
      await _supabase.from('cards_presidenti').delete().eq('id', id);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Errore eliminazione scheda presidente: $e');
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
                  'Schede Presidenti',
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
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            },
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('Assegnata a'),
                  _pdfHeaderCell('Rilasciata il'),
                  _pdfHeaderCell('Scadenza'),
                  _pdfHeaderCell('Data Creazione'),
                ],
              ),
              for (final card in cards)
                pw.TableRow(
                  children: [
                    _pdfCell(card['assigned_to'] as String? ?? ''),
                    _pdfCell(_formatOptionalDate(card['released_on'])),
                    _pdfCell(_formatOptionalDate(card['expires_on'])),
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
          .from('cards_presidenti')
          .select()
          .order('assigned_to');
      final bytes = await _generatePdf(items);
      if (!mounted) return;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'schede_presidenti_$dateStr.pdf',
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
        future: _supabase.from('cards_presidenti').select().order('assigned_to'),
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
              child: Text('Nessuna scheda presidente presente.'),
            );
          }

          final cards = snapshot.data!;
          final today = DateTime.now();

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
                    final assignedTo = card['assigned_to'] as String? ?? '';
                    final expiresOn = _parseDate(card['expires_on']);
                    final isExpired = expiresOn != null &&
                        expiresOn.isBefore(today);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.assignment_ind,
                          color: isExpired ? Colors.redAccent : Colors.blue,
                        ),
                        title: Text(
                          assignedTo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Rilasciata il: ${_formatOptionalDate(card['released_on'])}'
                          '  ·  Scadenza: ${_formatOptionalDate(card['expires_on'])}',
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
                              onPressed: () => _deleteCard(card['id'], assignedTo),
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
