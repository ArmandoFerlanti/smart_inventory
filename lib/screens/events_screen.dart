import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _supabase = Supabase.instance.client;

  // ===========================
  // FETCH
  // ===========================

  Future<List<Map<String, dynamic>>> _fetchEvents() async {
    return await _supabase.from('custom_events').select().order('created_at');
  }

  // ===========================
  // CREATE EVENT
  // ===========================

  void _showCreateEventDialog() {
    final nameController = TextEditingController();
    final List<Map<String, String>> columns = [
      {'name': '', 'type': 'testo'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          var isSaving = false;
          String? errorMessage;

          void addColumn() {
            dialogSetState(() {
              columns.add({'name': '', 'type': 'testo'});
            });
          }

          void removeColumn(int index) {
            if (columns.length <= 1) return;
            dialogSetState(() {
              columns.removeAt(index);
            });
          }

          Future<void> save() async {
            if (nameController.text.trim().isEmpty) {
              dialogSetState(() => errorMessage = 'Inserisci il nome dell\'evento.');
              return;
            }

            final validColumns = columns
                .where((c) => c['name']!.trim().isNotEmpty)
                .toList();
            if (validColumns.isEmpty) {
              dialogSetState(
                  () => errorMessage = 'Aggiungi almeno una colonna con un nome.');
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _supabase.from('custom_events').insert({
                'event_name': nameController.text.trim(),
                'schema_definition': jsonEncode(validColumns),
                'rows_data': jsonEncode([]),
              });
              if (mounted) {
                Navigator.pop(ctx);
                setState(() {});
              }
            } catch (e) {
              debugPrint('Errore creazione evento: $e');
              dialogSetState(() {
                isSaving = false;
                errorMessage = 'Errore: $e';
              });
            }
          }

          return AlertDialog(
            title: const Text('Nuovo Evento'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome Evento',
                      hintText: 'es. Raduno Estivo 2026',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Colonne:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        onPressed: addColumn,
                        icon: const Icon(Icons.add_circle),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Aggiungi colonna',
                      ),
                    ],
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: columns.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Nome colonna',
                                    isDense: true,
                                  ),
                                  onChanged: (val) =>
                                      columns[index]['name'] = val,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButton<String>(
                                  value: columns[index]['type'],
                                  isDense: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'testo', child: Text('Testo')),
                                    DropdownMenuItem(
                                        value: 'numero', child: Text('Numero')),
                                    DropdownMenuItem(
                                        value: 'data', child: Text('Data')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      dialogSetState(
                                          () => columns[index]['type'] = val);
                                    }
                                  },
                                ),
                              ),
                              if (columns.length > 1)
                                IconButton(
                                  onPressed: () => removeColumn(index),
                                  icon: const Icon(Icons.remove_circle_outline,
                                      size: 20),
                                  color: Colors.redAccent,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(errorMessage!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
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
                    : const Text('Crea'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================
  // DELETE EVENT
  // ===========================

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final name = event['event_name'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina evento'),
        content: Text(
            'Vuoi eliminare "$name" e tutti i suoi dati?'),
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
      await _supabase.from('custom_events').delete().eq('id', event['id']);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Errore eliminazione evento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore eliminazione: $e')),
        );
      }
    }
  }

  // ===========================
  // EVENT DETAIL
  // ===========================

  void _openEventDetail(Map<String, dynamic> event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EventDetailScreen(
          event: event,
          onRefresh: () => setState(() {}),
        ),
      ),
    );
  }

  // ===========================
  // BUILD
  // ===========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchEvents(),
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
              child: Text(
                  'Nessun evento creato. Premi + per crearne uno.'),
            );
          }

          final events = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final schema = jsonDecode(event['schema_definition'] as String? ?? '[]') as List;
              final rows = jsonDecode(event['rows_data'] as String? ?? '[]') as List;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      Icons.table_chart,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    event['event_name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${schema.length} colonne · ${rows.length} righe',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new, size: 20),
                        tooltip: 'Apri',
                        onPressed: () => _openEventDetail(event),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Elimina',
                        onPressed: () => _deleteEvent(event),
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
        onPressed: _showCreateEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ==================================================
// DETTAGLIO EVENTO (schermata separata)
// ==================================================

class _EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onRefresh;

  const _EventDetailScreen({required this.event, required this.onRefresh});

  @override
  State<_EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<_EventDetailScreen> {
  final _supabase = Supabase.instance.client;
  bool _isExporting = false;
  late List<Map<String, dynamic>> _columns;
  late List<Map<String, dynamic>> _rows;
  late String _eventName;
  String? _eventId;

  @override
  void initState() {
    super.initState();
    _eventName = widget.event['event_name'] ?? '';
    _eventId = widget.event['id'];
    _columns = (jsonDecode(
                widget.event['schema_definition'] as String? ?? '[]')
            as List)
        .map<Map<String, dynamic>>((c) => Map<String, dynamic>.from(c))
        .toList();
    _rows = (jsonDecode(widget.event['rows_data'] as String? ?? '[]') as List)
        .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  Future<void> _saveToDb() async {
    try {
      await _supabase.from('custom_events').update({
        'event_name': _eventName,
        'schema_definition': jsonEncode(_columns),
        'rows_data': jsonEncode(_rows),
      }).eq('id', _eventId!);
    } catch (e) {
      debugPrint('Errore salvataggio evento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore salvataggio: $e')),
        );
      }
    }
  }

  // ===========================
  // RIGHE
  // ===========================

  void _addRow() {
    if (_columns.isEmpty) return;
    final newRow = <String, dynamic>{};
    for (final col in _columns) {
      newRow[col['name'] as String] = '';
    }
    _rows.add(newRow);
    _saveToDb();
    setState(() {});
  }

  void _deleteRow(int index) {
    _rows.removeAt(index);
    _saveToDb();
    setState(() {});
  }

  void _editCell(int rowIndex, String colName, String type) {
    final controller = TextEditingController(
      text: _rows[rowIndex][colName]?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: Text('Modifica $colName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type == 'data')
                  _buildDateField(controller, dialogSetState)
                else
                  TextField(
                    controller: controller,
                    keyboardType: type == 'numero'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: colName,
                      hintText: type == 'numero'
                          ? '0.00'
                          : type == 'data'
                              ? 'GG/MM/AAAA'
                              : '',
                    ),
                    autofocus: true,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  _rows[rowIndex][colName] = controller.text;
                  _saveToDb();
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateField(
      TextEditingController controller, StateSetter dialogSetState) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: 'Data',
        hintText: 'GG/MM/AAAA',
        suffixIcon: Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () async {
        final parsed = _parseDate(controller.text);
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          dialogSetState(() {
            controller.text =
                '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
          });
        }
      },
    );
  }

  DateTime? _parseDate(String text) {
    try {
      final parts = text.split('/');
      if (parts.length == 3) {
        return DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return null;
  }

  // ===========================
  // COLONNE
  // ===========================

  void _showAddColumnDialog() {
    final nameController = TextEditingController();
    String type = 'testo';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: const Text('Aggiungi Colonna'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome colonna',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: type,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'testo', child: Text('Testo')),
                    DropdownMenuItem(value: 'numero', child: Text('Numero')),
                    DropdownMenuItem(value: 'data', child: Text('Data')),
                  ],
                  onChanged: (val) {
                    if (val != null) dialogSetState(() => type = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  _columns.add({
                    'name': nameController.text.trim(),
                    'type': type,
                  });
                  for (final row in _rows) {
                    row[nameController.text.trim()] = '';
                  }
                  _saveToDb();
                  Navigator.pop(ctx);
                  setState(() {});
                },
                child: const Text('Aggiungi'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeColumn(int index) async {
    final colName = _columns[index]['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovi colonna'),
        content: Text(
            'Vuoi rimuovere la colonna "$colName"? I dati associati saranno eliminati.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _columns.removeAt(index);
      for (final row in _rows) {
        row.remove(colName);
      }
      _saveToDb();
      setState(() {});
    }
  }

  // ===========================
  // PDF
  // ===========================

  pw.Widget _pdfHeaderCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child:
            pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _pdfCell(String text) =>
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(text));

  Future<Uint8List> _generatePdf() async {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final fontDataBold =
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final font = pw.Font.ttf(fontData);
    final fontBold = pw.Font.ttf(fontDataBold);

    final pdf = pw.Document();

    final colWidths = <int, pw.FlexColumnWidth>{};
    for (var i = 0; i < _columns.length; i++) {
      colWidths[i] = pw.FlexColumnWidth(
          6.0 / _columns.length);
    }

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
                pw.Text(_eventName,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generato il $dateStr',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Righe: ${_rows.length}',
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
            columnWidths: colWidths,
            border: pw.TableBorder.all(
                color: PdfColors.grey, width: 0.5),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  for (final col in _columns)
                    _pdfHeaderCell(col['name'] as String),
                ],
              ),
              for (final row in _rows)
                pw.TableRow(
                  children: [
                    for (final col in _columns)
                      _pdfCell(
                          row[col['name'] as String]?.toString() ?? ''),
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
      final bytes = await _generatePdf();
      if (!mounted) return;
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final safeName = _eventName.replaceAll(RegExp(r'[^\w]'), '_');
      await Printing.sharePdf(
          bytes: bytes, filename: '${safeName}_$dateStr.pdf');
    } catch (e) {
      debugPrint('Errore export PDF: $e');
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
      appBar: AppBar(
        title: Text(_eventName),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.view_column_outlined, size: 20),
            tooltip: 'Aggiungi colonna',
            onPressed: _showAddColumnDialog,
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf, size: 20),
            tooltip: 'Esporta PDF',
            onPressed: _isExporting ? null : _exportPdf,
          ),
        ],
      ),
      body: _columns.isEmpty
          ? const Center(
              child: Text('Nessuna colonna. Aggiungine una dall\'icona in alto.'),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    for (var i = 0; i < _columns.length; i++)
                      DataColumn(
                        label: GestureDetector(
                          onTap: () => _removeColumn(i),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _columns[i]['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.close,
                                  size: 14,
                                  color: Colors.redAccent.withAlpha(150)),
                            ],
                          ),
                        ),
                      ),
                    const DataColumn(
                      label: SizedBox.shrink(),
                    ),
                  ],
                  rows: [
                    for (var r = 0; r < _rows.length; r++)
                      DataRow(
                        cells: [
                          for (final col in _columns)
                            DataCell(
                              GestureDetector(
                                onTap: () => _editCell(
                                  r,
                                  col['name'] as String,
                                  col['type'] as String,
                                ),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minWidth: 60),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    _formatCellValue(
                                        _rows[r][col['name']]
                                                ?.toString() ??
                                            '',
                                        col['type'] as String),
                                    style: _rows[r][col['name']]
                                                ?.toString()
                                                .isEmpty ==
                                            true
                                        ? TextStyle(
                                            color: Colors.grey.withAlpha(100),
                                            fontStyle: FontStyle.italic)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18),
                              onPressed: () => _deleteRow(r),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatCellValue(String value, String type) {
    if (value.isEmpty) {
      if (type == 'data') return 'GG/MM/AAAA';
      if (type == 'numero') return '0';
      return '-';
    }
    return value;
  }
}
