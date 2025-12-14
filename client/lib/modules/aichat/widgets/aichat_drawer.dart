import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mydatatools/database_manager.dart';
import 'package:mydatatools/models/tables/chat_session.dart';

class AiChatDrawer extends StatefulWidget {
  const AiChatDrawer({super.key});

  @override
  State<AiChatDrawer> createState() => _AiChatDrawer();
}

class _AiChatDrawer extends State<AiChatDrawer> {
  List<ChatSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions =
        await DatabaseManager.instance.repository!.getSessionsWithMessages();
    if (mounted) {
      setState(() {
        _sessions = sessions;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox.expand(
      child: Container(
        height: double.infinity,
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Text("History", style: theme.textTheme.titleMedium),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  // If we had a title column, we'd use it. For now, use ID or date.
                  final title =
                      session.title ??
                      'Session ${session.createdAt.toLocal().toString().split('.')[0]}';
                  final currentSessionId =
                      GoRouterState.of(
                        context,
                      ).uri.queryParameters['sessionId'];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    selected: session.id == currentSessionId,
                    selectedTileColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.2),
                    title: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            session.id == currentSessionId
                                ? FontWeight.bold
                                : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Text(
                      session.model ?? '',
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () {
                      context.go('/aichat?sessionId=${session.id}');
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                context.go('/aichat/settings');
              },
            ),
          ],
        ),
      ),
    );
  }
}
