import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tecnm_chat/core/constants/app_constants.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/user_model.dart';
import 'package:tecnm_chat/features/chat/controllers/chat_controller.dart';
import 'package:tecnm_chat/features/contacts/controllers/contacts_controller.dart';
import 'package:tecnm_chat/features/conversations/controllers/conversations_controller.dart';
import 'package:tecnm_chat/features/groups/controllers/groups_controller.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String conversationId;

  const GroupDetailScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final convAsync = ref.watch(conversationProvider(conversationId));
    final meAsync = ref.watch(currentUserProvider);

    return convAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (conv) {
        if (conv == null || !conv.isGroup) {
          return const Scaffold(
              body: Center(child: Text('Grupo no encontrado')));
        }

        final isAdmin = conv.adminUid == myUid;
        final isProfessor = meAsync.valueOrNull?.isProfessor ?? false;
        final canAddMembers = isAdmin && isProfessor;
        final hidePhones = conv.hidePhoneNumbers;
        final participantsKey = conv.participants.join(',');
        final membersAsync =
            ref.watch(conversationParticipantsProvider(participantsKey));
        final messagesAsync = ref.watch(messagesProvider(conversationId));

        final mediaMessages = messagesAsync.valueOrNull
                ?.where((m) =>
                    m.mediaUrl != null &&
                    (m.type == AppConstants.msgImage ||
                        m.type == AppConstants.msgVideo))
                .toList() ??
            [];

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Detalles del grupo')),
          body: ListView(
            children: [
              // ── Header ──────────────────────────────────────────────
              _GroupHeader(
                name: conv.groupName ?? 'Grupo',
                avatarUrl: conv.groupAvatarUrl,
                memberCount: conv.participants.length,
              ),
              const Divider(height: 1),

              // ── Miembros ────────────────────────────────────────────
              _SectionHeader(
                title: 'Miembros (${conv.participants.length})',
                action: canAddMembers
                    ? TextButton.icon(
                        icon: const Icon(Icons.person_add_outlined, size: 16),
                        label: const Text('Agregar'),
                        onPressed: () => _showAddMembersSheet(
                          context,
                          ref,
                          conv.participants,
                        ),
                      )
                    : null,
              ),
              membersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const SizedBox.shrink(),
                data: (usersMap) {
                  final members = conv.participants
                      .map((uid) => usersMap[uid])
                      .whereType<UserModel>()
                      .toList();

                  return Column(
                    children: members.map((user) {
                      return _MemberTile(
                        user: user,
                        isAdmin: user.uid == conv.adminUid,
                        hidePhone: hidePhones,
                        isMe: user.uid == myUid,
                      );
                    }).toList(),
                  );
                },
              ),
              const Divider(height: 1),

              // ── Multimedia ──────────────────────────────────────────
              const _SectionHeader(title: 'Multimedia'),
              if (mediaMessages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 32, horizontal: 24),
                  child: Column(
                    children: [
                      Icon(Icons.perm_media_outlined,
                          size: 48, color: AppTheme.textFaint),
                      const SizedBox(height: 12),
                      const Text(
                        'Sin imágenes ni videos compartidos',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: mediaMessages.length,
                    itemBuilder: (context, i) {
                      final msg = mediaMessages[i];
                      return _MediaThumbnail(
                        url: msg.mediaUrl!,
                        isVideo: msg.type == AppConstants.msgVideo,
                        onTap: msg.type == AppConstants.msgImage
                            ? () => _showImageDialog(context, msg.mediaUrl!)
                            : null,
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMembersSheet(
    BuildContext context,
    WidgetRef ref,
    List<String> currentUids,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddMembersSheet(
        conversationId: conversationId,
        currentUids: currentUids,
      ),
    );
  }
}

// ── Widgets privados ─────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int memberCount;

  const _GroupHeader({
    required this.name,
    required this.avatarUrl,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.surfaceAlt,
            backgroundImage:
                avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(Icons.group, size: 52, color: AppTheme.textSecondary)
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$memberCount miembro${memberCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionHeader({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          ?action,
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final UserModel user;
  final bool isAdmin;
  final bool hidePhone;
  final bool isMe;

  const _MemberTile({
    required this.user,
    required this.isAdmin,
    required this.hidePhone,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppTheme.surfaceAlt,
        backgroundImage: user.avatarUrl != null
            ? CachedNetworkImageProvider(user.avatarUrl!)
            : null,
        child: user.avatarUrl == null
            ? Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              )
            : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              isMe ? '${user.displayName} (tú)' : user.displayName,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.isProfessor ? 'Docente · ${user.career}' : 'Alumno · ${user.career}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          if (!hidePhone)
            Text(
              user.phoneNumber,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textFaint),
            ),
        ],
      ),
      isThreeLine: !hidePhone,
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  final String url;
  final bool isVideo;
  final VoidCallback? onTap;

  const _MediaThumbnail({
    required this.url,
    required this.isVideo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          fit: StackFit.expand,
          children: [
            isVideo
                ? Container(
                    color: Colors.black,
                    child: const Icon(Icons.videocam,
                        color: Colors.white54, size: 32),
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.surfaceAlt,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.surfaceAlt,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppTheme.textFaint),
                    ),
                  ),
            if (isVideo)
              const Center(
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Hoja de agregar miembros ─────────────────────────────────────────────────

class _AddMembersSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final List<String> currentUids;

  const _AddMembersSheet({
    required this.conversationId,
    required this.currentUids,
  });

  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final Set<String> _selected = {};
  bool _loading = false;

  Future<void> _submit() async {
    if (_selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      await addMembersToGroup(
        conversationId: widget.conversationId,
        newUids: _selected.toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Agregar miembros',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('Agregar (${_selected.length})'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: contactsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (contacts) {
                  final available = contacts
                      .where((u) => !widget.currentUids.contains(u.uid))
                      .toList();

                  if (available.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Todos tus contactos ya están en el grupo.',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: available.length,
                    itemBuilder: (context, i) {
                      final user = available[i];
                      final selected = _selected.contains(user.uid);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.surfaceAlt,
                          backgroundImage: user.avatarUrl != null
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  user.displayName.isNotEmpty
                                      ? user.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary),
                                )
                              : null,
                        ),
                        title: Text(user.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          user.isProfessor ? 'Docente' : 'Alumno',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Checkbox(
                          value: selected,
                          activeColor: AppTheme.primary,
                          onChanged: (_) => setState(() {
                            if (selected) {
                              _selected.remove(user.uid);
                            } else {
                              _selected.add(user.uid);
                            }
                          }),
                        ),
                        onTap: () => setState(() {
                          if (selected) {
                            _selected.remove(user.uid);
                          } else {
                            _selected.add(user.uid);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
