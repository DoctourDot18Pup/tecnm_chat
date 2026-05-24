import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/features/stories/controllers/stories_controller.dart';

class AddStoryScreen extends ConsumerStatefulWidget {
  const AddStoryScreen({super.key});

  @override
  ConsumerState<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends ConsumerState<AddStoryScreen> {
  File? _mediaFile;
  bool _isImage = true;
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, bool isImage) async {
    final picker = ImagePicker();
    XFile? picked;

    if (isImage) {
      picked = await picker.pickImage(source: source, imageQuality: 80);
    } else {
      picked = await picker.pickVideo(source: source);
    }

    if (picked != null) {
      setState(() {
        _mediaFile = File(picked!.path);
        _isImage = isImage;
      });
    }
  }

  void _showPickOptions() {
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
                _pickMedia(ImageSource.camera, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Imagen de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _publish() {
    if (_mediaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una imagen o video.')),
      );
      return;
    }

    ref.read(storiesControllerProvider.notifier).uploadStory(
          mediaFile: _mediaFile!,
          caption: _captionController.text,
          isImage: _isImage,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StoryUploadState>(storiesControllerProvider, (_, state) {
      if (state is StoryUploaded) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story publicado correctamente.')),
        );
      } else if (state is StoryError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });

    final isLoading =
        ref.watch(storiesControllerProvider) is StoryUploading;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Nuevo story',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _publish,
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
                    'Publicar',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _mediaFile == null
                ? Center(
                    child: ElevatedButton.icon(
                      onPressed: _showPickOptions,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Seleccionar media'),
                    ),
                  )
                : _isImage
                    ? Image.file(
                        _mediaFile!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.videocam,
                              size: 80,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _mediaFile!.path.split('/').last,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _showPickOptions,
                              child: const Text(
                                'Cambiar archivo',
                                style: TextStyle(color: AppTheme.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          if (_mediaFile != null)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Agrega una leyenda (opcional)...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  prefixIcon:
                      Icon(Icons.edit, color: Colors.white54),
                ),
                maxLength: 200,
                maxLines: 2,
              ),
            ),
          if (_mediaFile == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '💡 Comparte avances de proyectos, avisos académicos o logros.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
