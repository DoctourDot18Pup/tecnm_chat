import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/user_model.dart';
import 'package:tecnm_chat/features/contacts/controllers/contacts_controller.dart';
import 'package:tecnm_chat/features/groups/controllers/groups_controller.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  File? _avatarFile;
  bool _hidePhoneNumbers = false;
  final Set<String> _selectedUids = {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un participante.'),
        ),
      );
      return;
    }

    ref.read(groupsControllerProvider.notifier).createGroup(
          groupName: _nameController.text.trim(),
          participantUids: _selectedUids.toList(),
          hidePhoneNumbers: _hidePhoneNumbers,
          avatarFile: _avatarFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GroupState>(groupsControllerProvider, (_, state) {
      if (state is GroupCreated) {
        context.go('/chat/${state.conversationId}');
      } else if (state is GroupError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isLoading = ref.watch(groupsControllerProvider) is GroupLoading;

    if (currentUser != null && !currentUser.isProfessor) {
      return Scaffold(
        appBar: AppBar(title: const Text('Crear grupo')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64, color: AppTheme.textSecondary),
                SizedBox(height: 16),
                Text(
                  'Solo los profesores pueden crear grupos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final contactsAsync = ref.watch(contactsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear grupo'),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _submit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Crear',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.surface,
                  backgroundImage:
                      _avatarFile != null ? FileImage(_avatarFile!) : null,
                  child: _avatarFile == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 32,
                          color: AppTheme.primary,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del grupo *',
                prefixIcon: Icon(Icons.group),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa un nombre.' : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Ocultar números telefónicos'),
              subtitle: const Text(
                'Los integrantes no verán los números telefónicos.',
              ),
              value: _hidePhoneNumbers,
              onChanged: (v) => setState(() => _hidePhoneNumbers = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Seleccionar participantes:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Text(
                    'No tienes contactos. Agrega contactos primero.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  );
                }

                return Column(
                  children: contacts.map((user) {
                    final selected = _selectedUids.contains(user.uid);
                    return _ContactSelectTile(
                      user: user,
                      selected: selected,
                      onToggle: () {
                        setState(() {
                          if (selected) {
                            _selectedUids.remove(user.uid);
                          } else {
                            _selectedUids.add(user.uid);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactSelectTile extends StatelessWidget {
  final UserModel user;
  final bool selected;
  final VoidCallback onToggle;

  const _ContactSelectTile({
    required this.user,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.surface,
        backgroundImage: user.avatarUrl != null
            ? CachedNetworkImageProvider(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: AppTheme.primary),
              )
            : null,
      ),
      title: Text(user.displayName),
      subtitle: Text(
        user.isProfessor ? 'Profesor' : 'Alumno',
        style: TextStyle(
          color: user.isProfessor ? AppTheme.accent : AppTheme.primary,
          fontSize: 12,
        ),
      ),
      trailing: Checkbox(
        value: selected,
        onChanged: (_) => onToggle(),
        activeColor: AppTheme.primary,
      ),
      onTap: onToggle,
    );
  }
}
