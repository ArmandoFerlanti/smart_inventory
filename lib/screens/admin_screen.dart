import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _adminService = AdminService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _users = await _adminService.listUsers();
    } catch (e) {
      _error = 'Errore nel caricamento utenti: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.redAccent;
      case 'presidente':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'presidente':
        return Icons.assignment_ind;
      default:
        return Icons.person;
    }
  }

  // ===========================
  // CREATE USER DIALOG
  // ===========================

  void _showCreateUserDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'presidente';
    var isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Future<void> save() async {
            final email = emailController.text.trim();
            final password = passwordController.text;

            if (email.isEmpty || !email.contains('@')) {
              dialogSetState(() => errorMessage = 'Inserisci una email valida.');
              return;
            }
            if (password.length < 6) {
              dialogSetState(
                () => errorMessage =
                    'La password deve avere almeno 6 caratteri.',
              );
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _adminService.createUser(email, password, selectedRole);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadUsers();
              _showSnack('Utente creato con successo.');
            } catch (e) {
              debugPrint('Errore creazione utente: $e');
              dialogSetState(() {
                isSaving = false;
                errorMessage = _adminService.formatError(e);
              });
            }
          }

          return AlertDialog(
            title: const Text('Nuovo Utente'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password (min. 6 caratteri)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'presidente',
                      child: Text('Presidente'),
                    ),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'membro', child: Text('Membro')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      dialogSetState(() => selectedRole = val);
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
                    : const Text('Crea'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================
  // EDIT USER DIALOG
  // ===========================

  void _showEditUserDialog(Map<String, dynamic> user) {
    final emailController = TextEditingController(text: user['email']);
    String selectedRole = user['role'];
    var isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Future<void> save() async {
            final email = emailController.text.trim();

            if (email.isEmpty || !email.contains('@')) {
              dialogSetState(() => errorMessage = 'Inserisci una email valida.');
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _adminService.updateUser(user['id'], email, selectedRole);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadUsers();
              _showSnack('Utente aggiornato.');
            } catch (e) {
              debugPrint('Errore aggiornamento utente: $e');
              dialogSetState(() {
                isSaving = false;
                errorMessage = _adminService.formatError(e);
              });
            }
          }

          return AlertDialog(
            title: const Text('Modifica Utente'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'presidente',
                      child: Text('Presidente'),
                    ),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'membro', child: Text('Membro')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      dialogSetState(() => selectedRole = val);
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
  // RESET PASSWORD DIALOG
  // ===========================

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passwordController = TextEditingController();
    var isSaving = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Future<void> save() async {
            final password = passwordController.text;

            if (password.length < 6) {
              dialogSetState(
                () => errorMessage =
                    'La password deve avere almeno 6 caratteri.',
              );
              return;
            }

            dialogSetState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await _adminService.resetPassword(user['id'], password);
              if (ctx.mounted) Navigator.pop(ctx);
              _showSnack('Password reimpostata con successo.');
            } catch (e) {
              debugPrint('Errore reset password: $e');
              dialogSetState(() {
                isSaving = false;
                errorMessage = _adminService.formatError(e);
              });
            }
          }

          return AlertDialog(
            title: Text('Reset Password - ${user['email']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onSubmitted: (_) => save(),
                  decoration: const InputDecoration(
                    labelText: 'Nuova password (min. 6 caratteri)',
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
                    : const Text('Reimposta'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================
  // DELETE USER
  // ===========================

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Utente'),
        content: Text(
          'Vuoi eliminare definitivamente l\'utente ${user['email']}?',
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
      await _adminService.deleteUser(user['id']);
      _loadUsers();
      _showSnack('Utente eliminato.');
    } catch (e) {
      _showSnack('Errore eliminazione: $e', error: true);
    }
  }

  // ===========================
  // BUILD
  // ===========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadUsers,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: _users.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(child: Text('Nessun utente trovato.')),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final role = user['role'] as String? ?? 'membro';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  _roleIcon(role),
                                  color: _roleColor(role),
                                ),
                                title: Text(
                                  user['email'] as String? ?? '(senza email)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Ruolo: ${role.toUpperCase()}'
                                  '${user['created_at'] != null ? '  ·  Creato il ${_formatDate(DateTime.parse(user['created_at']))}' : ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Modifica',
                                      onPressed: () =>
                                          _showEditUserDialog(user),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.lock_reset),
                                      tooltip: 'Reset Password',
                                      onPressed: () =>
                                          _showResetPasswordDialog(user),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Elimina',
                                      onPressed: () => _deleteUser(user),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
