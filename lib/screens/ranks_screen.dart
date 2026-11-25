// RANKS — leaderboard (friends + global) and the habit-only Gym Crew chat.
//
// "Habit-only" is a rule, not a suggestion: the chat is for asking people
// doing the same habit how they do it. It is not a general chat and not a
// dating app. In v1 the data is local demo data; Firebase (groups +
// messages) replaces it later — see firebase_backend.dart.

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class RanksScreen extends StatefulWidget {
  const RanksScreen({super.key, required this.state});

  final AppState state;

  @override
  State<RanksScreen> createState() => _RanksScreenState();
}

class _RanksScreenState extends State<RanksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _messageController = TextEditingController();
  bool _friendsOnly = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.emerald,
          unselectedLabelColor:
              Theme.of(context).textTheme.bodySmall?.color,
          indicatorColor: AppTheme.emerald,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'Gym Crew chat'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _LeaderboardTab(
                state: widget.state,
                friendsOnly: _friendsOnly,
                onScopeChanged: (value) {
                  setState(() => _friendsOnly = value);
                },
              ),
              _ChatTab(
                state: widget.state,
                controller: _messageController,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({
    required this.state,
    required this.friendsOnly,
    required this.onScopeChanged,
  });

  final AppState state;
  final bool friendsOnly;
  final ValueChanged<bool> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final entries =
        friendsOnly ? state.leaderboard : state.globalLeaderboard;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            const Text('Scope: '),
            ChoiceChip(
              label: const Text('Friends'),
              selected: friendsOnly,
              onSelected: (_) => onScopeChanged(true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Global'),
              selected: !friendsOnly,
              onSelected: (_) => onScopeChanged(false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Leaderboard is demo data until Firebase is connected — '
          'your XP updates live as you complete habits.',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        const SectionTitle('How XP works'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rateRow('Study', '${state.xpRates.studyPerHour} XP / hour'),
              _rateRow('Gym', '${state.xpRates.gymPerHour} XP / hour'),
              _rateRow('Wake up early', '${state.xpRates.wakePerDay} XP / day'),
              _rateRow('Sleep on time', '${state.xpRates.sleepPerDay} XP / day'),
              _rateRow(
                'Water',
                '${state.xpRates.waterPer500ml} XP / 500 ml · max ${state.xpRates.waterMaxPerDay} / day',
              ),
              const SizedBox(height: 6),
              const Text(
                'XP is proportional: half the time = half the XP. '
                '0:00 = 0 XP. The owner can edit any rate in Settings.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SectionTitle('This week'),
        for (var i = 0; i < entries.length; i++)
          _RankRow(rank: i + 1, entry: entries[i]),
      ],
    );
  }

  Widget _rateRow(String name, String rate) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name),
            Text(rate, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '#$rank';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(medal, style: const TextStyle(fontSize: 18)),
            ),
            Expanded(
              child: Text(
                entry.name,
                style: TextStyle(
                  fontWeight:
                      entry.isYou ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            XpChip('${entry.xp} XP'),
          ],
        ),
      ),
    );
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab({required this.state, required this.controller});

  final AppState state;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: AppTheme.emeraldSoft,
          child: const Text(
            'Gym Crew — habit-only chat. Ask how others do the habit. '
            'No general chat, no dating.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.emerald,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.chatMessages.length,
            itemBuilder: (context, i) {
              final message = state.chatMessages[i];
              final isYou = message.isYou;
              return Align(
                alignment:
                    isYou ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isYou
                        ? AppTheme.emerald
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isYou)
                        Text(
                          message.author,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.sky,
                          ),
                        ),
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isYou
                              ? Colors.white
                              : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Ask about the habit…',
                  ),
                  onSubmitted: (_) => _send(context),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _send(context),
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _send(BuildContext context) async {
    final text = controller.text;
    if (text.trim().isEmpty) return;
    final sent = await state.sendChatMessage(text);
    if (sent) {
      controller.clear();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.demoBlockedMessage ?? 'Message not sent.',
          ),
        ),
      );
    }
  }
}
