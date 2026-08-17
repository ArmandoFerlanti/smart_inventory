import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isExporting = false;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  static const String _euroSign = '\u20AC';

  final List<String> _monthNames = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatCurrency(num value) {
    final formatter =
        NumberFormat.currency(locale: 'it_IT', symbol: '$_euroSign ');
    return formatter.format(value);
  }

  // ===========================
  // FETCH DATA
  // ===========================

  Future<List<Map<String, dynamic>>> _fetchMembers() async {
    return await _supabase.from('members').select().order('created_at');
  }

  Future<num> _fetchQuota() async {
    final data = await _supabase
        .from('quota_config')
        .select('amount')
        .eq('id', 1)
        .single();
    return (data['amount'] as num?) ?? 70;
  }

  Future<List<Map<String, dynamic>>> _fetchPayments() async {
    return await _supabase
        .from('member_payments')
        .select()
        .eq('month', _selectedMonth)
        .eq('year', _selectedYear);
  }

  Future<List<Map<String, dynamic>>> _fetchNotes(String memberId) async {
    return await _supabase
        .from('member_notes')
        .select()
        .eq('member_id', memberId)
        .order('created_at');
  }

  // ===========================
  // CRUD SOCI
  // ===========================

  void _showAddMemberDialog() {
    final nomeController = TextEditingController();
    final cognomeController = TextEditingController();
    final roadnameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? errorMessage;

          Future<void> save() async {
            if (nomeController.text.trim().isEmpty) {
              dialogSetState(() => errorMessage = 'Inserisci il nome.');
              return;
            }
            if (cognomeController.text.trim().isEmpty) {
              dialogSetState(() => errorMessage = 'Inserisci il cognome.');
              return;
            }
            if (roadnameController.text.trim().isEmpty) {
              dialogSetState(
                  () => errorMessage = 'Inserisci il roadname.');
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              final member = await _supabase
                  .from('members')
                  .insert({
                    'nome': nomeController.text.trim(),
                    'cognome': cognomeController.text.trim(),
                    'roadname': roadnameController.text.trim(),
                  })
                  .select()
                  .single();

              final now = DateTime.now();
              await _supabase.from('member_payments').insert({
                'member_id': member['id'],
                'month': now.month,
                'year': now.year,
                'paid': false,
              });

              if (mounted) {
                Navigator.pop(ctx);
                setState(() {});
              }
            } catch (e) {
              debugPrint('Errore salvataggio socio: $e');
              dialogSetState(() {
                isSaving = false;
                if (e.toString().contains('duplicate key') ||
                    e.toString().contains('unique')) {
                  errorMessage = 'Esiste già un socio con questo roadname.';
                } else {
                  errorMessage = 'Errore: $e';
                }
              });
            }
          }

          return AlertDialog(
            title: const Text('Aggiungi Socio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: cognomeController,
                  decoration: const InputDecoration(labelText: 'Cognome'),
                ),
                TextField(
                  controller: roadnameController,
                  decoration: const InputDecoration(
                    labelText: 'Roadname',
                    hintText: 'Soprannome univoco',
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

  void _showEditMemberDialog(Map<String, dynamic> member) {
    final nomeController =
        TextEditingController(text: member['nome'] as String);
    final cognomeController =
        TextEditingController(text: member['cognome'] as String);
    final roadnameController =
        TextEditingController(text: member['roadname'] as String);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? errorMessage;

          Future<void> save() async {
            if (nomeController.text.trim().isEmpty) {
              dialogSetState(() => errorMessage = 'Inserisci il nome.');
              return;
            }
            if (cognomeController.text.trim().isEmpty) {
              dialogSetState(() => errorMessage = 'Inserisci il cognome.');
              return;
            }
            if (roadnameController.text.trim().isEmpty) {
              dialogSetState(
                  () => errorMessage = 'Inserisci il roadname.');
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _supabase.from('members').update({
                'nome': nomeController.text.trim(),
                'cognome': cognomeController.text.trim(),
                'roadname': roadnameController.text.trim(),
              }).eq('id', member['id']);

              if (mounted) {
                Navigator.pop(ctx);
                setState(() {});
              }
            } catch (e) {
              debugPrint('Errore modifica socio: $e');
              dialogSetState(() {
                isSaving = false;
                if (e.toString().contains('duplicate key') ||
                    e.toString().contains('unique')) {
                  errorMessage = 'Esiste già un socio con questo roadname.';
                } else {
                  errorMessage = 'Errore: $e';
                }
              });
            }
          }

          return AlertDialog(
            title: const Text('Modifica Socio'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: cognomeController,
                  decoration: const InputDecoration(labelText: 'Cognome'),
                ),
                TextField(
                  controller: roadnameController,
                  decoration: const InputDecoration(labelText: 'Roadname'),
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

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    final name = '${member['nome']} ${member['cognome']}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina socio'),
        content: Text(
            'Vuoi eliminare "$name" e tutti i suoi dati (note, pagamenti)?'),
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
      await _supabase.from('members').delete().eq('id', member['id']);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Errore eliminazione socio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore eliminazione: $e')),
        );
      }
    }
  }

  // ===========================
  // NOTE
  // ===========================

  void _showMemberNotesDialog(Map<String, dynamic> member) {
    final noteController = TextEditingController();
    final name = '${member['nome']} ${member['cognome']}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Future<List<Map<String, dynamic>>> notesFuture =
              _fetchNotes(member['id']);

          Future<void> addNote() async {
            if (noteController.text.trim().isEmpty) return;
            try {
              await _supabase.from('member_notes').insert({
                'member_id': member['id'],
                'note_text': noteController.text.trim(),
              });
              noteController.clear();
              dialogSetState(() {
                notesFuture = _fetchNotes(member['id']);
              });
            } catch (e) {
              debugPrint('Errore aggiunta nota: $e');
            }
          }

          Future<void> deleteNote(String noteId) async {
            try {
              await _supabase.from('member_notes').delete().eq('id', noteId);
              dialogSetState(() {
                notesFuture = _fetchNotes(member['id']);
              });
            } catch (e) {
              debugPrint('Errore eliminazione nota: $e');
            }
          }

          return AlertDialog(
            title: Text('Note - $name'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            hintText: 'Nuova nota...',
                          ),
                          onSubmitted: (_) => addNote(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: addNote,
                        icon: const Icon(Icons.add_circle),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: notesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final notes = snapshot.data ?? [];
                        if (notes.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Nessuna nota.'),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            final dateStr = note['created_at'] != null
                                ? DateFormat('dd/MM/yyyy').format(
                                    DateTime.parse(note['created_at']))
                                : '';
                            return Card(
                              child: ListTile(
                                title: Text(note['note_text'] ?? ''),
                                subtitle: Text(dateStr,
                                    style: const TextStyle(fontSize: 11)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  onPressed: () => deleteNote(note['id']),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Chiudi'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================
  // QUOTA CONFIG
  // ===========================

  void _showEditQuotaDialog(num currentQuota) {
    final controller =
        TextEditingController(text: currentQuota.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? error;

          Future<void> save() async {
            final value =
                double.tryParse(controller.text.replaceAll(',', '.'));
            if (value == null || value <= 0) {
              dialogSetState(() => error = 'Inserisci un importo valido.');
              return;
            }
            dialogSetState(() {
              isSaving = true;
              error = null;
            });
            try {
              await _supabase.from('quota_config').update({
                'amount': value,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', 1);
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {});
              }
            } catch (e) {
              dialogSetState(() {
                isSaving = false;
                error = 'Errore: $e';
              });
            }
          }

          return AlertDialog(
            title: const Text('Modifica Quota Mensile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Importo quota',
                    prefixText: '$_euroSign ',
                  ),
                  autofocus: true,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: const TextStyle(color: Colors.redAccent)),
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
  // PAGAMENTO TOGGLE
  // ===========================

  Future<void> _togglePayment(
      String memberId, bool currentPaid) async {
    try {
      final existing = await _supabase
          .from('member_payments')
          .select('id')
          .eq('member_id', memberId)
          .eq('month', _selectedMonth)
          .eq('year', _selectedYear)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('member_payments').update({
          'paid': !currentPaid,
        }).eq('id', existing['id']);
      } else {
        await _supabase.from('member_payments').insert({
          'member_id': memberId,
          'month': _selectedMonth,
          'year': _selectedYear,
          'paid': !currentPaid,
        });
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Errore toggle pagamento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore aggiornamento pagamento: $e')),
        );
      }
    }
  }

  // ===========================
  // PDF EXPORT
  // ===========================

  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child:
            pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _pdfCell(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text));

  Future<Uint8List> _generateMembersPdf(
      List<Map<String, dynamic>> members) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final fontData =
        await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final fontDataBold =
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontDataBold);

    final pdf = pw.Document();

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
                pw.Text('Elenco Soci Sede',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generato il $dateStr',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Totale soci: ${members.length}',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber} di ${context.pagesCount}',
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(3),
            },
            border: pw.TableBorder.all(
                color: PdfColors.grey, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('Nome'),
                  _pdfHeaderCell('Cognome'),
                  _pdfHeaderCell('Roadname'),
                ],
              ),
              for (final m in members)
                pw.TableRow(
                  children: [
                    _pdfCell(m['nome'] as String? ?? ''),
                    _pdfCell(m['cognome'] as String? ?? ''),
                    _pdfCell(m['roadname'] as String? ?? ''),
                  ],
                ),
            ],
          ),
          for (final m in members) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Note - ${m['nome']} ${m['cognome']}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> _generatePaymentsPdf(
      List<Map<String, dynamic>> members,
      List<Map<String, dynamic>> payments,
      num quota) async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final monthStr = '${_monthNames[_selectedMonth - 1]} $_selectedYear';

    final fontData =
        await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final fontDataBold =
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontDataBold);

    final paymentMap = <String, bool>{};
    for (final p in payments) {
      paymentMap[p['member_id'] as String] = p['paid'] as bool;
    }

    final paidCount = members
        .where((m) => paymentMap[m['id']] == true)
        .length;

    final pdf = pw.Document();

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
                pw.Text('Quote Mensili - $monthStr',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generato il $dateStr',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Quota: ${_formatCurrency(quota)}  ·  Totale: ${members.length}  ·  Pagati: $paidCount  ·  Non pagati: ${members.length - paidCount}',
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey700),
            ),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Pagina ${context.pageNumber} di ${context.pagesCount}',
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(2.5),
              3: pw.FlexColumnWidth(1.5),
            },
            border: pw.TableBorder.all(
                color: PdfColors.grey, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('Nome'),
                  _pdfHeaderCell('Cognome'),
                  _pdfHeaderCell('Roadname'),
                  _pdfHeaderCell('Quota'),
                ],
              ),
              for (final m in members)
                pw.TableRow(
                  children: [
                    _pdfCell(m['nome'] as String? ?? ''),
                    _pdfCell(m['cognome'] as String? ?? ''),
                    _pdfCell(m['roadname'] as String? ?? ''),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        paymentMap[m['id']] == true ? 'SI' : 'NO',
                        style: pw.TextStyle(
                          color: paymentMap[m['id']] == true
                              ? PdfColors.green700
                              : PdfColors.red700,
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

  Future<void> _exportMembersPdf() async {
    setState(() => _isExporting = true);
    try {
      final members = await _fetchMembers();
      final bytes = await _generateMembersPdf(members);
      if (!mounted) return;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
          bytes: bytes, filename: 'soci_$dateStr.pdf');
    } catch (e) {
      debugPrint('Errore export PDF soci: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore export PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPaymentsPdf(num quota) async {
    setState(() => _isExporting = true);
    try {
      final members = await _fetchMembers();
      final payments = await _fetchPayments();
      final bytes = await _generatePaymentsPdf(members, payments, quota);
      if (!mounted) return;
      final monthStr =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      await Printing.sharePdf(
          bytes: bytes, filename: 'quote_$monthStr.pdf');
    } catch (e) {
      debugPrint('Errore export PDF quote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore export PDF: $e')));
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
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Soci', icon: Icon(Icons.people)),
              Tab(text: 'Quote', icon: Icon(Icons.receipt_long)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSociTab(),
                _buildQuoteTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMemberDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ===========================
  // TAB SOCI
  // ===========================

  Widget _buildSociTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchMembers(),
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
            child: Text('Nessun socio presente. Premi + per aggiungerne.'),
          );
        }

        final members = snapshot.data!;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _isExporting ? null : _exportMembersPdf,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(
                      _isExporting ? 'Generazione...' : 'Esporta PDF'),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          '${(member['nome'] as String).isNotEmpty ? member['nome'][0] : ''}${(member['cognome'] as String).isNotEmpty ? member['cognome'][0] : ''}',
                        ),
                      ),
                      title: Text(
                        '${member['nome']} ${member['cognome']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(member['roadname'] ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 20),
                            tooltip: 'Modifica',
                            onPressed: () =>
                                _showEditMemberDialog(member),
                          ),
                          IconButton(
                            icon: const Icon(Icons.sticky_note_2_outlined,
                                size: 20),
                            tooltip: 'Note',
                            onPressed: () =>
                                _showMemberNotesDialog(member),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20),
                            tooltip: 'Elimina',
                            onPressed: () => _deleteMember(member),
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
    );
  }

  // ===========================
  // TAB QUOTE
  // ===========================

  Widget _buildQuoteTab() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _fetchMembers(),
        _fetchPayments(),
        _fetchQuota(),
      ]),
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

        final members = (snapshot.data![0] as List<Map<String, dynamic>>);
        final payments = (snapshot.data![1] as List<Map<String, dynamic>>);
        final quota = snapshot.data![2] as num;

        if (members.isEmpty) {
          return const Center(
            child: Text(
                'Nessun socio presente. Aggiungilo nella tab "Soci".'),
          );
        }

        final paymentMap = <String, bool>{};
        for (final p in payments) {
          paymentMap[p['member_id'] as String] = p['paid'] as bool;
        }

        return Column(
          children: [
            // Selettore mese/anno + quota + PDF
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  // Mese
                  DropdownButton<int>(
                    value: _selectedMonth,
                    items: List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_monthNames[i],
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMonth = val);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // Anno
                  DropdownButton<int>(
                    value: _selectedYear,
                    items: List.generate(
                      5,
                      (i) => DropdownMenuItem(
                        value: DateTime.now().year - 2 + i,
                        child: Text('${DateTime.now().year - 2 + i}',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedYear = val);
                      }
                    },
                  ),
                  const Spacer(),
                  // Quota attuale
                  InkWell(
                    onTap: () => _showEditQuotaDialog(quota),
                    child: Row(
                      children: [
                        Text(
                          'Quota: ${_formatCurrency(quota)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.edit_outlined,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .primary),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // PDF
                  OutlinedButton.icon(
                    onPressed: _isExporting
                        ? null
                        : () => _exportPaymentsPdf(quota),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('PDF',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Tabella quote
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                          label: Text('Nome',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Cognome',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Roadname',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Quota Pagata',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold))),
                    ],
                    rows: members.map((member) {
                      final paid =
                          paymentMap[member['id']] ?? false;
                      return DataRow(cells: [
                        DataCell(Text(member['nome'] ?? '')),
                        DataCell(Text(member['cognome'] ?? '')),
                        DataCell(Text(member['roadname'] ?? '')),
                        DataCell(
                          GestureDetector(
                            onTap: () => _togglePayment(
                                member['id'], paid),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: paid
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: Text(
                                paid ? 'SI' : 'NO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
