import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isExporting = false;

  static const String _euroSign = '\u20AC';

  String _formatCurrency(num value) {
    final formatter = NumberFormat.currency(locale: 'it_IT', symbol: '$_euroSign ');
    return formatter.format(value);
  }

  String _formatDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<num> _fetchBalance() async {
    final data = await _supabase.from('treasury_balance').select('balance').eq('id', 1).single();
    return (data['balance'] as num?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> _fetchMovements() async {
    return await _supabase.from('treasury_movements').select().order('created_at', ascending: false);
  }

  Future<void> _refreshAll() async {
    if (mounted) setState(() {});
  }

  // --- Edit Balance ---
  void _showEditBalanceDialog(num currentBalance) {
    final controller = TextEditingController(text: currentBalance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? error;

          Future<void> save() async {
            final value = double.tryParse(controller.text.replaceAll(',', '.'));
            if (value == null) {
              dialogSetState(() => error = 'Inserisci un numero valido.');
              return;
            }
            dialogSetState(() { isSaving = true; error = null; });
            try {
              await _supabase.from('treasury_balance').update({
                'balance': value,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', 1);
              if (mounted) { Navigator.pop(ctx); _refreshAll(); }
            } catch (e) {
              dialogSetState(() { isSaving = false; error = 'Errore: $e'; });
            }
          }

          return AlertDialog(
            title: const Text('Modifica Saldo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Nuovo saldo',
                    prefixText: '$_euroSign ',
                  ),
                  autofocus: true,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Add Movement ---
  void _showAddMovementDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String type = 'entrata';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? error;

          Future<void> save() async {
            final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
            if (descController.text.trim().isEmpty) {
              dialogSetState(() => error = 'Inserisci una descrizione.');
              return;
            }
            if (amount == null || amount <= 0) {
              dialogSetState(() => error = 'Inserisci un importo valido maggiore di 0.');
              return;
            }
            dialogSetState(() { isSaving = true; error = null; });
            try {
              await _supabase.from('treasury_movements').insert({
                'type': type,
                'amount': amount,
                'description': descController.text.trim(),
              });

              final current = await _fetchBalance();
              final delta = type == 'entrata' ? amount : -amount;
              await _supabase.from('treasury_balance').update({
                'balance': current + delta,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', 1);

              if (mounted) { Navigator.pop(ctx); _refreshAll(); }
            } catch (e) {
              dialogSetState(() { isSaving = false; error = 'Errore: $e'; });
            }
          }

          return AlertDialog(
            title: const Text('Nuovo Movimento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'entrata', label: Text('Entrata'), icon: Icon(Icons.arrow_downward)),
                    ButtonSegment(value: 'uscita', label: Text('Uscita'), icon: Icon(Icons.arrow_upward)),
                  ],
                  selected: {type},
                  onSelectionChanged: (sel) => dialogSetState(() => type = sel.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importo',
                    prefixText: '$_euroSign ',
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Delete Movement ---
  Future<void> _deleteMovement(Map<String, dynamic> movement) async {
    final desc = movement['description'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina movimento'),
        content: Text('Vuoi eliminare "$desc"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Elimina')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final current = await _fetchBalance();
      final type = movement['type'] as String;
      final amount = (movement['amount'] as num).toDouble();
      final delta = type == 'entrata' ? -amount : amount;
      await _supabase.from('treasury_balance').update({
        'balance': current + delta,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);

      await _supabase.from('treasury_movements').delete().eq('id', movement['id']);

      _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore eliminazione: $e')));
      }
    }
  }

  // --- PDF Export ---
  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
  );

  pw.Widget _pdfCell(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text));

  Future<Uint8List> _generatePdf(num balance, List<Map<String, dynamic>> movements) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final pdf = pw.Document();

    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final fontDataBold = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontDataBold);

    final totalEntrate = movements
        .where((m) => m['type'] == 'entrata')
        .fold<num>(0, (s, m) => s + (m['amount'] as num));
    final totalUscite = movements
        .where((m) => m['type'] == 'uscita')
        .fold<num>(0, (s, m) => s + (m['amount'] as num));

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
                pw.Text('Tesoreria Sede',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generato il $dateStr', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Saldo attuale: ${_formatCurrency(balance)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Totale entrate: ${_formatCurrency(totalEntrate)}  \u00B7  Totale uscite: ${_formatCurrency(totalUscite)}  \u00B7  Movimenti: ${movements.length}',
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
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(2),
            },
            border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('Data'),
                  _pdfHeaderCell('Descrizione'),
                  _pdfHeaderCell('Tipo'),
                  _pdfHeaderCell('Importo'),
                ],
              ),
              for (final m in movements)
                pw.TableRow(
                  children: [
                    _pdfCell(_formatDate(DateTime.parse(m['created_at']))),
                    _pdfCell(m['description'] as String? ?? ''),
                    _pdfCell((m['type'] as String).toUpperCase()),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '${m['type'] == 'uscita' ? '-' : '+'}${_formatCurrency(m['amount'])}',
                        style: pw.TextStyle(
                          color: m['type'] == 'entrata' ? PdfColors.green700 : PdfColors.red700,
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
      final balance = await _fetchBalance();
      final movements = await _fetchMovements();
      final bytes = await _generatePdf(balance, movements);
      if (!mounted) return;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await Printing.sharePdf(bytes: bytes, filename: 'tesoreria_$dateStr.pdf');
    } catch (e) {
      debugPrint('Errore export PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore export PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Color _movementColor(String type) {
    switch (type) {
      case 'entrata':
        return Colors.green;
      case 'uscita':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _movementIcon(String type) {
    switch (type) {
      case 'entrata':
        return Icons.arrow_downward;
      case 'uscita':
        return Icons.arrow_upward;
      default:
        return Icons.edit;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: Future.wait([_fetchBalance(), _fetchMovements()]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Errore nel caricamento: ${snapshot.error}\n\nAssicurati di aver creato le tabelle treasury_balance e treasury_movements su Supabase.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            );
          }

          final balance = (snapshot.data![0] as num);
          final movements = (snapshot.data![1] as List<Map<String, dynamic>>);

          return Column(
            children: [
              // --- Balance Card ---
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: InkWell(
                    onTap: () => _showEditBalanceDialog(balance),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_wallet,
                              size: 36, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Saldo Attuale',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatCurrency(balance),
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: balance >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Modifica saldo',
                            onPressed: () => _showEditBalanceDialog(balance),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- Action Buttons ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddMovementDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Nuovo Movimento'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _isExporting ? null : _exportPdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(_isExporting ? '...' : 'PDF'),
                    ),
                  ],
                ),
              ),

              // --- Movements List ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Movimenti (${movements.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: movements.isEmpty
                    ? const Center(child: Text('Nessun movimento registrato.'))
                    : ListView.builder(
                        itemCount: movements.length,
                        itemBuilder: (context, index) {
                          final m = movements[index];
                          final type = m['type'] as String;
                          final amount = (m['amount'] as num).toDouble();
                          final color = _movementColor(type);
                          final dateStr = m['created_at'] != null
                              ? _formatDate(DateTime.parse(m['created_at']))
                              : '';
                          final prefix = type == 'uscita' ? '-' : '+';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withAlpha(51),
                                child: Icon(_movementIcon(type), color: color, size: 20),
                              ),
                              title: Text(
                                m['description'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$prefix${_formatCurrency(amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: color,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    tooltip: 'Elimina',
                                    onPressed: () => _deleteMovement(m),
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
        onPressed: _showAddMovementDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
