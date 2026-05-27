import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Global / Weekly leaderboard screen.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;
  bool _offline = false;
  bool _weekly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _weekly = _tabController.index == 1);
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final entries =
          await ApiService.instance.getLeaderboard(weekly: _weekly);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = e.isOffline;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = true;
      });
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg =>
      _isDark ? const Color(0xFF191919) : const Color(0xFFF4F4F4);
  Color get _cardBg =>
      _isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);

  @override
  Widget build(BuildContext context) {
    final myId = ApiService.instance.currentPlayerId;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Leaderboard',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: _textSecondary,
          tabs: const [
            Tab(text: 'Global'),
            Tab(text: 'Weekly'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: _accent,
        onRefresh: _load,
        child: _buildBody(myId),
      ),
    );
  }

  Widget _buildBody(String? myId) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_offline || _entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.signal_wifi_off_rounded,
                size: 56,
                color: _textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                _offline
                    ? 'Leaderboard not available offline'
                    : 'No players yet',
                style: TextStyle(color: _textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isMe = entry.id == myId;
        return _LeaderboardCard(
          entry: entry,
          isMe: isMe,
          isDark: _isDark,
          cardBg: isMe ? const Color(0xFF3A3020) : _cardBg,
          accent: _accent,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
        );
      },
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.entry,
    required this.isMe,
    required this.isDark,
    required this.cardBg,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final bool isDark;
  final Color cardBg;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    final rankColor = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
            ? const Color(0xFFC0C0C0)
            : entry.rank == 3
                ? const Color(0xFFCD7F32)
                : textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? accent.withAlpha(150)
              : (isDark
                  ? const Color(0xFF3B3B3B)
                  : const Color(0xFFDDDDDD)),
          width: isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rankColor,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: accent.withAlpha(60),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                              fontSize: 10,
                              color: accent,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Chapter ${entry.chapter} · Prestige ${entry.prestigeLevel}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalStrength}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: accent,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.bolt_rounded, size: 16, color: accent),
        ],
      ),
    );
  }
}
