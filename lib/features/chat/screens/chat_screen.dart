import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/conversation_model.dart';
import 'package:tecnm_chat/data/models/message_model.dart';
import 'package:tecnm_chat/features/chat/controllers/chat_controller.dart';
import 'package:tecnm_chat/features/conversations/controllers/conversations_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const ChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmoji = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatControllerProvider(widget.conversationId))
          .markAsRead();
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    // Limpiar indicador de escritura al salir del chat
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'typingUsers.$uid': FieldValue.delete()})
          .catchError((_) {});
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final controller =
        ref.read(chatControllerProvider(widget.conversationId));
    if (text.isEmpty) {
      _typingTimer?.cancel();
      controller.setTyping(false);
      return;
    }
    controller.setTyping(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(seconds: 3),
      () => controller.setTyping(false),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickMedia() async {
    final controller = ref.read(chatControllerProvider(widget.conversationId));
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () async {
                Navigator.pop(context);
                final picked =
                    await picker.pickImage(source: ImageSource.camera);
                if (picked != null) {
                  await controller.sendImageMessage(File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Imagen de galería'),
              onTap: () async {
                Navigator.pop(context);
                final picked =
                    await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  await controller.sendImageMessage(File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video de galería'),
              onTap: () async {
                Navigator.pop(context);
                final picked =
                    await picker.pickVideo(source: ImageSource.gallery);
                if (picked != null) {
                  await controller.sendVideoMessage(File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Documento PDF'),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final name = result.files.single.name;
                  await controller.sendFileMessage(file, name);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final conversationAsync =
        ref.watch(conversationProvider(widget.conversationId));
    final typingAsync = ref.watch(typingProvider(widget.conversationId));
    final controller = ref.read(chatControllerProvider(widget.conversationId));

    final typingUids = typingAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: conversationAsync.when(
          loading: () => const Text('Cargando...'),
          error: (error, stack) => const Text('Chat'),
          data: (conv) =>
              _buildAppBarTitle(conv, myUid, ref, typingUids),
        ),
        actions: [
          conversationAsync.maybeWhen(
            data: (conv) {
              if (conv == null) return const SizedBox.shrink();
              if (conv.isGroup) {
                return IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () => context.push('/group/${conv.id}/detail'),
                );
              }
              final otherUid = conv.participants
                  .firstWhere((u) => u != myUid, orElse: () => '');
              if (otherUid.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.videocam),
                  onPressed: () => context.push('/call/$otherUid'),
                );
              }
              return const SizedBox.shrink();
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                final hidePhones = conversationAsync.valueOrNull
                        ?.hidePhoneNumbers ??
                    false;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Di hola 👋',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderUid == myUid;
                    return _MessageBubble(
                      message: msg,
                      isMine: isMine,
                      hidePhones: hidePhones,
                    );
                  },
                );
              },
            ),
          ),
          if (_showEmoji)
            SizedBox(
              height: 300,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  _textController.text += emoji.emoji;
                },
                config: const Config(
                  height: 300,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                  ),
                ),
              ),
            ),
          _buildInputBar(controller),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                color: AppTheme.primary,
              ),
              onPressed: () => setState(() => _showEmoji = !_showEmoji),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onChanged: _onTextChanged,
                onTap: () {
                  if (_showEmoji) setState(() => _showEmoji = false);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppTheme.primary),
              onPressed: _pickMedia,
            ),
            CircleAvatar(
              backgroundColor: AppTheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () {
                  final text = _textController.text;
                  if (text.trim().isEmpty) return;
                  _textController.clear();
                  _typingTimer?.cancel();
                  controller.setTyping(false);
                  controller.sendTextMessage(text);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarTitle(
    ConversationModel? conv,
    String myUid,
    WidgetRef ref,
    List<String> typingUids,
  ) {
    if (conv == null) return const Text('Chat');

    if (conv.isGroup) {
      final isAnyoneTyping =
          typingUids.any((uid) => uid != myUid);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(conv.groupName ?? 'Grupo'),
          if (isAnyoneTyping)
            const Text(
              'Escribiendo...',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      );
    }

    final otherUid =
        conv.participants.firstWhere((u) => u != myUid, orElse: () => '');
    if (otherUid.isEmpty) return const Text('Chat');

    final isOtherTyping = typingUids.contains(otherUid);
    final usersAsync = ref.watch(conversationParticipantsProvider(otherUid));

    return usersAsync.when(
      loading: () => const Text('Cargando...'),
      error: (error, stack) => const Text('Chat'),
      data: (users) {
        final name = users[otherUid]?.displayName ?? 'Usuario';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name),
            if (isOtherTyping)
              const Text(
                'Escribiendo...',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool hidePhones;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.hidePhones,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case AppConstants.msgEmoji:
        return Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.content, style: const TextStyle(fontSize: 40)),
            _TimeRow(message: message, isMine: isMine),
          ],
        );

      case AppConstants.msgImage:
        if (message.mediaUrl == null) return const SizedBox.shrink();
        return _BubbleContainer(
          isMine: isMine,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        );

      case AppConstants.msgVideo:
        if (message.mediaUrl == null) return const SizedBox.shrink();
        return _BubbleContainer(
          isMine: isMine,
          child: _VideoThumbnail(url: message.mediaUrl!),
        );

      case AppConstants.msgFile:
        if (message.mediaUrl == null) return const SizedBox.shrink();
        return _FileBubble(message: message, isMine: isMine);

      default:
        return _BubbleContainer(
          isMine: isMine,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  color: isMine ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              _TimeRow(message: message, isMine: isMine),
            ],
          ),
        );
    }
  }
}

/// Fila de hora + paloma de lectura para mensajes propios.
class _TimeRow extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _TimeRow({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final isRead = message.readBy.length > 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('HH:mm').format(message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: isMine ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        if (isMine) ...[
          const SizedBox(width: 3),
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 13,
            color: isRead ? Colors.white : Colors.white54,
          ),
        ],
      ],
    );
  }
}

class _BubbleContainer extends StatelessWidget {
  final bool isMine;
  final Widget child;

  const _BubbleContainer({required this.isMine, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMine ? AppTheme.bubbleSent : AppTheme.bubbleReceived,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        border: isMine
            ? null
            : Border.all(color: AppTheme.hairline, width: 1),
      ),
      child: child,
    );
  }
}

class _FileBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _FileBubble({required this.message, required this.isMine});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(message.mediaUrl!);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el archivo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: _BubbleContainer(
        isMine: isMine,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 32,
              color: isMine ? Colors.white70 : Colors.red.shade700,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMine ? Colors.white : AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PDF · Toca para abrir',
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine ? Colors.white54 : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String url;

  const _VideoThumbnail({required this.url});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            const CircleAvatar(
              radius: 24,
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
        ],
      ),
    );
  }
}
