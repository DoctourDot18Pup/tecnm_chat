import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/user_model.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  File? _avatarFile;
  String? _career;
  int? _semester;
  bool _initialized = false;

  void _initialize(UserModel user) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = user.displayName;
    _emailController.text = user.institutionalEmail;
    _career = user.career;
    _semester = user.semester;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    final lower = email.toLowerCase();
    return AppConstants.validEmailDomains
        .any((domain) => lower.endsWith('@$domain'));
  }

  void _submit(UserModel user) {
    if (!_formKey.currentState!.validate()) return;

    ref.read(profileControllerProvider.notifier).updateProfile(
          displayName: _nameController.text.trim(),
          institutionalEmail: _emailController.text.trim(),
          career: _career ?? user.career,
          semester: user.isStudent ? _semester : null,
          avatarFile: _avatarFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileState>(profileControllerProvider, (_, state) {
      if (state is ProfileSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente.')),
        );
        context.pop();
      } else if (state is ProfileError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final userAsync = ref.watch(currentUserProvider);
    final isLoading = ref.watch(profileControllerProvider) is ProfileLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const SizedBox.shrink();
          _initialize(user);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showAvatarOptions,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: AppTheme.surface,
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : user.avatarUrl != null
                                  ? CachedNetworkImageProvider(user.avatarUrl!)
                                  : null,
                          child: (_avatarFile == null && user.avatarUrl == null)
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppTheme.accent,
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ingresa tu nombre.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo institucional *',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa tu correo institucional.';
                      }
                      if (!_isValidEmail(v.trim())) {
                        return 'Usa un correo @itcelaya.edu.mx o @teccelaya.edu.mx';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _career,
                    decoration: const InputDecoration(
                      labelText: 'Carrera *',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: AppConstants.careers
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _career = v),
                  ),
                  if (user.isStudent) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _semester,
                      decoration: const InputDecoration(
                        labelText: 'Semestre',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      hint: const Text('Selecciona tu semestre'),
                      items: List.generate(
                        9,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('${i + 1}° semestre'),
                        ),
                      ),
                      onChanged: (v) => setState(() => _semester = v),
                    ),
                  ],
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isLoading ? null : () => _submit(user),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
