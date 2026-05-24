import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/conversation_model.dart';
import 'package:tecnm_chat/features/board/controllers/board_controller.dart';
import 'package:tecnm_chat/features/conversations/controllers/conversations_controller.dart';
import 'package:tecnm_chat/features/stories/widgets/stories_bar.dart';

enum _Tab { todos, noLeidos, grupos, tablon }

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  _Tab _tab = _Tab.todos;

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final boardAsync = ref.watch(boardPostsProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final unreadBoardCount = boardAsync.valueOrNull
            ?.where((p) => !p.readBy.contains(myUid))
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Conversaciones',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.contacts_outlined),
                    color: AppTheme.textPrimary,
                    onPressed: () => context.push('/contacts'),
                    tooltip: 'Contactos',
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    color: AppTheme.textPrimary,
                    onPressed: () => context.push('/profile'),
                    tooltip: 'Perfil',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Filter tabs ────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _Tab.todos,
                  _Tab.noLeidos,
                  _Tab.grupos,
                  _Tab.tablon,
                ].map((tab) {
                  final badge =
                      tab == _Tab.tablon && unreadBoardCount > 0
                          ? unreadBoardCount
                          : null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _TabChip(
                      label: _tabLabel(tab),
                      selected: _tab == tab,
                      badge: badge,
                      onTap: () {
                        if (tab == _Tab.tablon) {
                          context.push('/board');
                        } else {
                          setState(() => _tab = tab);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            // ── Stories bar ────────────────────────────────────────
            if (_tab == _Tab.todos || _tab == _Tab.noLeidos)
              const StoriesBar(),
            // ── List ───────────────────────────────────────────────
            Expanded(
              child: conversationsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (conversations) {
                  final filtered = _filter(conversations);
                  if (filtered.isEmpty) {
                    return _EmptyState(tab: _tab);
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      return _ConversationTile(
                        conversation: conv,
                        myUid: myUid,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatOptions(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  List<ConversationModel> _filter(List<ConversationModel> all) {
    switch (_tab) {
      case _Tab.todos:
        return all;
      case _Tab.noLeidos:
        return all
            .where((c) =>
                c.lastMessage != null && c.lastMessage!.isNotEmpty)
            .toList();
      case _Tab.grupos:
        return all.where((c) => c.isGroup).toList();
      case _Tab.tablon:
        return [];
    }
  }

  String _tabLabel(_Tab tab) {
    switch (tab) {
      case _Tab.todos:
        return 'Todos';
      case _Tab.noLeidos:
        return 'No leídos';
      case _Tab.grupos:
        return 'Grupos';
      case _Tab.tablon:
        return 'Tablón';
    }
  }

  void _showNewChatOptions(BuildContext context) {
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nueva conversación',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_outline,
                    color: AppTheme.textPrimary, size: 20),
              ),
              title: const Text(
                'Mensaje directo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text('Enviar mensaje a un contacto',
                  style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                context.push('/contacts');
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_outlined,
                    color: AppTheme.textPrimary, size: 20),
              ),
              title: const Text(
                'Nuevo grupo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text('Solo disponible para profesores',
                  style: TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                context.push('/group/create');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int? badge;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : AppTheme.textSecondary,
                letterSpacing: -0.2,
              ),
            ),
            if (badge != null && badge! > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withAlpha(60)
                      : AppTheme.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _Tab tab;

  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab == _Tab.grupos
                ? Icons.group_outlined
                : Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textFaint,
          ),
          const SizedBox(height: 16),
          Text(
            tab == _Tab.grupos
                ? 'No hay grupos'
                : tab == _Tab.noLeidos
                    ? 'Todo al día'
                    : 'Aún no tienes conversaciones',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tab == _Tab.grupos
                ? 'Los profesores pueden crear grupos'
                : tab == _Tab.noLeidos
                    ? 'No tienes mensajes sin leer'
                    : 'Agrega contactos para iniciar un chat',
            style: const TextStyle(
              color: AppTheme.textFaint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;
  final String myUid;

  const _ConversationTile({
    required this.conversation,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUids =
        conversation.participants.where((uid) => uid != myUid).toList();

    if (conversation.isGroup) {
      return _buildTile(
        context: context,
        name: conversation.groupName ?? 'Grupo',
        subtitle: conversation.lastMessage ?? 'Sin mensajes',
        avatarUrl: conversation.groupAvatarUrl,
        isGroup: true,
        lastTime: conversation.lastMessageAt,
      );
    }

    if (otherUids.isEmpty) return const SizedBox.shrink();

    final usersAsync = ref.watch(
      conversationParticipantsProvider(otherUids.join(',')),
    );

    return usersAsync.when(
      loading: () => const ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.surfaceAlt,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: Text('Cargando...'),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (users) {
        final other = users[otherUids.first];
        return _buildTile(
          context: context,
          name: other?.displayName ?? 'Usuario',
          subtitle: conversation.lastMessage ?? 'Sin mensajes',
          avatarUrl: other?.avatarUrl,
          isGroup: false,
          lastTime: conversation.lastMessageAt,
        );
      },
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required String name,
    required String subtitle,
    String? avatarUrl,
    required bool isGroup,
    DateTime? lastTime,
  }) {
    return InkWell(
      onTap: () => context.push('/chat/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.surfaceAlt,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Icon(
                      isGroup ? Icons.group : Icons.person,
                      color: AppTheme.textSecondary,
                      size: 26,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Time
            if (lastTime != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatTime(lastTime),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat('EEE', 'es').format(dt);
    }
    return DateFormat('dd/MM').format(dt);
  }
}
