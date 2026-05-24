import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/board_post_model.dart';
import 'package:tecnm_chat/features/board/controllers/board_controller.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class AcademicBoardScreen extends ConsumerStatefulWidget {
  const AcademicBoardScreen({super.key});

  @override
  ConsumerState<AcademicBoardScreen> createState() =>
      _AcademicBoardScreenState();
}

class _AcademicBoardScreenState extends ConsumerState<AcademicBoardScreen> {
  String? _filterType;

  static const _types = ['tarea', 'aviso', 'examen', 'material'];

  static const _typeLabels = {
    'tarea': 'Tarea',
    'aviso': 'Aviso',
    'examen': 'Examen',
    'material': 'Material',
  };

  static const _typeColors = {
    'tarea': Color(0xFF1A2540),
    'aviso': Color(0xFF0B0B0B),
    'examen': Color(0xFFB71C1C),
    'material': Color(0xFF2E7D32),
  };

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(boardPostsProvider);
    final userAsync = ref.watch(currentUserProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isProfessor =
        userAsync.valueOrNull?.isProfessor ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Tablón académico'),
        actions: [
          if (isProfessor)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => _showPublishSheet(context),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Publicar'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _FilterChip(
                  label: 'Todos',
                  selected: _filterType == null,
                  onTap: () => setState(() => _filterType = null),
                ),
                ..._types.map((t) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChip(
                        label: _typeLabels[t]!,
                        selected: _filterType == t,
                        onTap: () =>
                            setState(() => _filterType = _filterType == t ? null : t),
                      ),
                    )),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: postsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (posts) {
                final filtered = _filterType == null
                    ? posts
                    : posts.where((p) => p.type == _filterType).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 64, color: AppTheme.textFaint),
                        const SizedBox(height: 16),
                        Text(
                          'Sin publicaciones',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 16),
                        ),
                        if (isProfessor) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Toca "Publicar" para crear un anuncio',
                            style: TextStyle(
                                color: AppTheme.textFaint, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final post = filtered[i];
                    // mark as read on first visible render
                    if (!post.readBy.contains(myUid)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(boardControllerProvider.notifier)
                            .markAsRead(post.id);
                      });
                    }
                    return _PostCard(
                      post: post,
                      myUid: myUid,
                      typeColor: _typeColors[post.type] ?? AppTheme.primary,
                      typeLabel: _typeLabels[post.type] ?? post.type,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPublishSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PublishSheet(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.hairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final BoardPostModel post;
  final String myUid;
  final Color typeColor;
  final String typeLabel;

  const _PostCard({
    required this.post,
    required this.myUid,
    required this.typeColor,
    required this.typeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !post.readBy.contains(myUid);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? AppTheme.primary : AppTheme.hairline,
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.authorName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(post.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.body,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            if (post.deadline != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule,
                        size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 5),
                    Text(
                      'Entrega: ${DateFormat('d MMM, HH:mm', 'es').format(post.deadline!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (post.fileUrl != null && post.fileName != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(post.fileUrl!);
                  if (!await launchUrl(uri,
                      mode: LaunchMode.externalApplication)) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('No se pudo abrir el archivo.')),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attach_file,
                          size: 15, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          post.fileName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.open_in_new,
                          size: 13, color: AppTheme.textFaint),
                    ],
                  ),
                ),
              ),
            ],
            if (post.totalParticipants > 0) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      size: 13, color: AppTheme.textFaint),
                  const SizedBox(width: 4),
                  Text(
                    'Leído por ${post.readBy.length}/${post.totalParticipants}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textFaint,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE', 'es').format(dt);
    }
    return DateFormat('d/MM', 'es').format(dt);
  }
}

class _PublishSheet extends ConsumerStatefulWidget {
  const _PublishSheet();

  @override
  ConsumerState<_PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends ConsumerState<_PublishSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _type = 'aviso';
  DateTime? _deadline;
  File? _attachmentFile;
  String? _attachmentName;

  static const _types = {
    'tarea': 'Tarea',
    'aviso': 'Aviso',
    'examen': 'Examen',
    'material': 'Material',
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() => _deadline = DateTime(
        date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx'],
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _attachmentFile = File(result.files.single.path!);
      _attachmentName = result.files.single.name;
    });
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa el título y contenido.')),
      );
      return;
    }
    await ref.read(boardControllerProvider.notifier).createPost(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: _type,
          deadline: _deadline,
          attachmentFile: _attachmentFile,
          attachmentName: _attachmentName,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(boardControllerProvider) is AsyncLoading;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: bottomInset + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nueva publicación',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _types.entries.map((e) {
                final sel = _type == e.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _type = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: sel ? AppTheme.primary : AppTheme.hairline,
                        ),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Título'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            decoration: const InputDecoration(labelText: 'Contenido'),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDeadline,
            icon: const Icon(Icons.schedule, size: 16),
            label: Text(
              _deadline == null
                  ? 'Agregar fecha límite (opcional)'
                  : 'Entrega: ${DateFormat('d MMM, HH:mm', 'es').format(_deadline!)}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          // File attachment
          if (_attachmentName != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachmentName!,
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() {
                          _attachmentFile = null;
                          _attachmentName = null;
                        }),
                    child: const Icon(Icons.close,
                        size: 18, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.attach_file, size: 16),
            label: Text(
              _attachmentName == null
                  ? 'Adjuntar archivo (PDF, Word, PPT…)'
                  : 'Cambiar archivo',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Publicar'),
            ),
          ),
        ],
      ),
    );
  }
}
