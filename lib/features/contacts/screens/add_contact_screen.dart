import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/user_model.dart';
import 'package:tecnm_chat/features/contacts/controllers/contacts_controller.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _searchController = TextEditingController();
  bool _searchByEmail = false;

  @override
  void dispose() {
    _searchController.dispose();
    ref.read(contactsControllerProvider.notifier).reset();
    super.dispose();
  }

  void _search() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    if (_searchByEmail) {
      ref.read(contactsControllerProvider.notifier).searchByEmail(query);
    } else {
      ref.read(contactsControllerProvider.notifier).searchByPhone(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(contactsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar contacto')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Teléfono'),
                        icon: Icon(Icons.phone),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Correo'),
                        icon: Icon(Icons.email),
                      ),
                    ],
                    selected: {_searchByEmail},
                    onSelectionChanged: (s) {
                      setState(() {
                        _searchByEmail = s.first;
                        _searchController.clear();
                        ref.read(contactsControllerProvider.notifier).reset();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    keyboardType: _searchByEmail
                        ? TextInputType.emailAddress
                        : TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: _searchByEmail
                          ? 'usuario@itcelaya.edu.mx'
                          : '1234567890',
                      prefixIcon: Icon(
                        _searchByEmail ? Icons.email_outlined : Icons.phone,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (searchState is ContactSearchLoading)
              const Center(child: CircularProgressIndicator()),
            if (searchState is ContactSearchNotFound)
              const Center(
                child: Text(
                  'No se encontró ningún usuario con esos datos.',
                  textAlign: TextAlign.center,
                ),
              ),
            if (searchState is ContactSearchError)
              Text(
                searchState.message,
                style: const TextStyle(color: Colors.red),
              ),
            if (searchState is ContactSearchFound)
              _UserCard(user: searchState.user),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.surface,
              backgroundImage: user.avatarUrl != null
                  ? CachedNetworkImageProvider(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 22,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: user.isProfessor
                          ? AppTheme.accent.withValues(alpha: 0.15)
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      user.isProfessor ? 'Profesor' : 'Alumno',
                      style: TextStyle(
                        fontSize: 12,
                        color: user.isProfessor
                            ? AppTheme.accent
                            : AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.career,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await ref
                    .read(contactsControllerProvider.notifier)
                    .addContact(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${user.displayName} agregado a tus contactos.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Agregar'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
