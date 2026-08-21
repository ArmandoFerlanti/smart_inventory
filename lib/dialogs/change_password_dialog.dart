import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void showChangePasswordDialog(BuildContext context) {
  final oldController = TextEditingController();
  final newController = TextEditingController();
  final confirmController = TextEditingController();
  var isSaving = false;
  String? errorMessage;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, dialogSetState) {
        Future<void> save() async {
          final oldPassword = oldController.text;
          final newPassword = newController.text;
          final confirmPassword = confirmController.text;

          if (oldPassword.isEmpty || newPassword.isEmpty) {
            dialogSetState(
              () => errorMessage = 'Compila tutti i campi.',
            );
            return;
          }
          if (newPassword.length < 6) {
            dialogSetState(
              () => errorMessage =
                  'La nuova password deve avere almeno 6 caratteri.',
            );
            return;
          }
          if (newPassword != confirmPassword) {
            dialogSetState(
              () => errorMessage = 'Le nuove password non coincidono.',
            );
            return;
          }

          dialogSetState(() {
            isSaving = true;
            errorMessage = null;
          });

          try {
            final client = Supabase.instance.client;
            final email = client.auth.currentUser?.email;

            // Verifica la vecchia password ri-autenticando l'utente
            if (email != null) {
              await client.auth.signInWithPassword(
                email: email,
                password: oldPassword,
              );
            }

            await client.auth.updateUser(
              UserAttributes(password: newPassword),
            );

            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password aggiornata con successo.'),
                ),
              );
            }
          } on AuthException catch (e) {
            dialogSetState(() {
              isSaving = false;
              if (e.code == 'invalid_credentials' ||
                  e.message.toLowerCase().contains('invalid login')) {
                errorMessage = 'La vecchia password non è corretta.';
              } else {
                errorMessage = 'Errore: ${e.message}';
              }
            });
          } catch (e) {
            debugPrint('Errore cambio password: $e');
            dialogSetState(() {
              isSaving = false;
              errorMessage = 'Errore inatteso: $e';
            });
          }
        }

        return AlertDialog(
          title: const Text('Cambia Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Vecchia password',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nuova password (min. 6 caratteri)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Conferma nuova password',
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
                  : const Text('Aggiorna'),
            ),
          ],
        );
      },
    ),
  );
}
