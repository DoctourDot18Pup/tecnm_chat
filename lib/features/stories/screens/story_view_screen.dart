import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tecnm_chat/data/models/story_model.dart';
import 'package:tecnm_chat/features/stories/controllers/stories_controller.dart';

class StoryViewScreen extends ConsumerStatefulWidget {
  final String authorUid;

  const StoryViewScreen({super.key, required this.authorUid});

  @override
  ConsumerState<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends ConsumerState<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  List<StoryModel> _stories = [];

  static const _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
  }

  void _startProgress() {
    _progressController.reset();
    _progressController.forward();
  }

  void _nextStory() {
    if (_currentIndex < _stories.length - 1) {
      setState(() => _currentIndex++);
      _startProgress();
    } else {
      context.pop();
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startProgress();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(contactStoriesProvider);

    return storiesAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
      data: (storiesByUser) {
        final stories = storiesByUser[widget.authorUid] ?? [];

        if (stories.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'No hay stories disponibles.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        if (_stories.isEmpty || _stories.length != stories.length) {
          _stories = stories;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startProgress();
            final story = stories[_currentIndex];
            ref
                .read(storiesControllerProvider.notifier)
                .markAsViewed(story.id);
          });
        }

        if (_currentIndex >= _stories.length) {
          _currentIndex = _stories.length - 1;
        }

        final story = _stories[_currentIndex];

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTapUp: (details) {
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width / 2) {
                _previousStory();
              } else {
                _nextStory();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: story.mediaUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(
                              _stories.length,
                              (i) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: i < _currentIndex
                                        ? 1.0
                                        : i == _currentIndex
                                            ? _progressController.value
                                            : 0.0,
                                    backgroundColor: Colors.white30,
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                    minHeight: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => context.pop(),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (story.caption != null && story.caption!.isNotEmpty)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                      child: Text(
                        story.caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          shadows: [
                            Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
