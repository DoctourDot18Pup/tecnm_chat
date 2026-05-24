import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tecnm_chat/core/theme/app_theme.dart';
import 'package:tecnm_chat/data/models/story_model.dart';
import 'package:tecnm_chat/data/models/user_model.dart';
import 'package:tecnm_chat/features/profile/controllers/profile_controller.dart';
import 'package:tecnm_chat/features/stories/controllers/stories_controller.dart';

class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(contactStoriesProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      height: 100,
      color: Colors.white,
      child: storiesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (error, stack) => const SizedBox.shrink(),
        data: (storiesByUser) {
          final entries = storiesByUser.entries.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: entries.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _MyStoryButton(myUid: myUid);
              }

              final entry = entries[index - 1];
              if (entry.key == myUid) return const SizedBox.shrink();

              return _StoryAvatar(
                authorUid: entry.key,
                stories: entry.value,
              );
            },
          );
        },
      ),
    );
  }
}

class _MyStoryButton extends ConsumerWidget {
  final String myUid;

  const _MyStoryButton({required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final myStoriesAsync = ref.watch(myStoriesProvider);
    final hasStories = myStoriesAsync.valueOrNull?.isNotEmpty == true;

    return GestureDetector(
      onTap: () => hasStories
          ? context.push('/story/$myUid')
          : context.push('/story/add'),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: hasStories
                        ? Border.all(color: AppTheme.accent, width: 2.5)
                        : null,
                    color: AppTheme.surface,
                  ),
                  child: userAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => const Icon(Icons.person),
                    data: (user) => CircleAvatar(
                      backgroundColor: AppTheme.surface,
                      backgroundImage: user?.avatarUrl != null
                          ? CachedNetworkImageProvider(user!.avatarUrl!)
                          : null,
                      child: user?.avatarUrl == null
                          ? const Icon(Icons.person, color: AppTheme.primary)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.primary,
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tu story',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryAvatar extends ConsumerWidget {
  final String authorUid;
  final List<StoryModel> stories;

  const _StoryAvatar({required this.authorUid, required this.stories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final allViewed = stories.every((s) => s.viewedBy.contains(myUid));

    return FutureBuilder<UserModel?>(
      future: _fetchUser(authorUid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return GestureDetector(
          onTap: () => context.push('/story/$authorUid'),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: allViewed ? Colors.grey.shade300 : AppTheme.primary,
                      width: 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppTheme.surface,
                    backgroundImage: user?.avatarUrl != null
                        ? CachedNetworkImageProvider(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            user?.displayName.isNotEmpty == true
                                ? user!.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    user?.displayName.split(' ').first ?? '...',
                    style: const TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<UserModel?> _fetchUser(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson(doc.data()!);
  }
}
