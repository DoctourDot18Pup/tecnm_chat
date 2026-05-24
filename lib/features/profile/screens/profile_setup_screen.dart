import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  File? _avatarFile;
  String _role = AppConstants.roleStudent;
  String? _career;
  int? _semester;

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_career == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona tu carrera.')),
      );
      return;
    }

    ref.read(profileControllerProvider.notifier).saveProfile(
          displayName: _nameController.text.trim(),
          institutionalEmail: _emailController.text.trim(),
          role: _role,
          career: _career!,
          semester: _semester,
          avatarFile: _avatarFile,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileState>(profileControllerProvider, (_, state) {
      if (state is ProfileSaved) {
        context.go('/home');
      } else if (state is ProfileError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final isLoading = ref.watch(profileControllerProvider) is ProfileLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Configura tu perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _showAvatarOptions,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: AppTheme.surface,
                  backgroundImage:
                      _avatarFile != null ? FileImage(_avatarFile!) : null,
                  child: _avatarFile == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 36,
                          color: AppTheme.primary,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _showAvatarOptions,
                child: const Text('Agregar foto de perfil'),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ingresa tu nombre.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo institucional *',
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'usuario@itcelaya.edu.mx',
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
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AppConstants.roleStudent,
                    child: Text('Alumno'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.roleProfessor,
                    child: Text('Profesor'),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _role = v!;
                  _semester = null;
                }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _career,
                decoration: const InputDecoration(
                  labelText: 'Carrera *',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                hint: const Text('Selecciona tu carrera'),
                items: AppConstants.careers
                    .map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _career = v),
              ),
              if (_role == AppConstants.roleStudent) ...[
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
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Guardar perfil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
