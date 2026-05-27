import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// PVP screen — challenge players, view battle history.
class PvpScreen extends StatefulWidget {
  const PvpScreen({super.key});

  @override
  State<PvpScreen> createState() => _PvpScreenState();
}

class _PvpScreenState extends State<PvpScreen> {
  final _challengeController = TextEditingController();
  List<Map<String, dynamic>> _battles = [];
  bool _loading = true;
  bool _offline = false;
  bool _challenging = false;
  String? _challengeError;
  Map<String, dynamic>? _lastResult; // battle result overlay data

  @override
  void initState() {
    super.initState();
    _loadBattles();
  }

  @override
  void dispose() {
    _challengeController.dispose();
    super.dispose();
  }

  Future<void> _loadBattles() async {
    setState(() {
      _loading = true;
      _offline = false;
    });
    try {
      final battles = await ApiService.instance.getPvpBattles();
      if (!mounted) return;
      setState(() {
        _battles = battles;
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

  Future<void> _challenge() async {
    final target = _challengeController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _challenging = true;
      _challengeError = null;
      _lastResult = null;
    });

    try {
      final result = await ApiService.instance.challengePvp(target);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _lastResult = result;
          _challengeController.clear();
        });
        await _loadBattles();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _challengeError = e.isOffline
            ? 'No internet connection.'
            : (e.message.isNotEmpty ? e.message : 'Challenge failed.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _challengeError = 'Unexpected error.');
    } finally {
      if (mounted) setState(() => _challenging = false);
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'PVP Battles',
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _loadBattles,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Challenge input
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _challengeController,
                            decoration: InputDecoration(
                              hintText: 'Enter username to challenge...',
                              prefixIcon:
                                  const Icon(Icons.sports_kabaddi_rounded),
                              filled: true,
                              fillColor: _isDark
                                  ? const Color(0xFF252525)
                                  : const Color(0xFFF0F0F0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 14),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _challenge(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _challenging ? null : _challenge,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB84040),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _challenging
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Challenge'),
                        ),
                      ],
                    ),
                    if (_challengeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _challengeError!,
                          style: const TextStyle(
                              color: Color(0xFFE07070), fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Battle history
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _offline
                        ? _buildOffline()
                        : _battles.isEmpty
                            ? Center(
                                child: Text(
                                  'No battles yet.\nChallenge someone!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _textSecondary),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadBattles,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _battles.length,
                                  itemBuilder: (context, index) =>
                                      _BattleCard(
                                    battle: _battles[index],
                                    myId:
                                        ApiService.instance.currentPlayerId ??
                                            '',
                                    isDark: _isDark,
                                    cardBg: _cardBg,
                                    textPrimary: _textPrimary,
                                    textSecondary: _textSecondary,
                                    accent: _accent,
                                  ),
                                ),
                              ),
              ),
            ],
          ),

          // Result overlay
          if (_lastResult != null)
            _BattleResultOverlay(
              result: _lastResult!,
              myId: ApiService.instance.currentPlayerId ?? '',
              accent: _accent,
              onDismiss: () => setState(() => _lastResult = null),
            ),
        ],
      ),
    );
  }

  Widget _buildOffline() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_wifi_off_rounded,
              size: 56, color: _textSecondary),
          const SizedBox(height: 16),
          Text(
            'PVP not available offline',
            style: TextStyle(color: _textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: _loadBattles,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _BattleCard extends StatelessWidget {
  const _BattleCard({
    required this.battle,
    required this.myId,
    required this.isDark,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  final Map<String, dynamic> battle;
  final String myId;
  final bool isDark;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final challenger =
        battle['challenger'] as Map<String, dynamic>? ?? {};
    final defender = battle['defender'] as Map<String, dynamic>? ?? {};
    final winnerId = battle['winner_id'] as String?;
    final iWon = winnerId == myId;
    final isChallenged = challenger['id'] == myId;

    final opponent = isChallenged ? defender : challenger;
    final opponentName = opponent['username'] as String? ?? 'Unknown';

    final winColor = const Color(0xFF7AC97A);
    final loseColor = const Color(0xFFE07070);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iWon
              ? winColor.withAlpha(120)
              : loseColor.withAlpha(120),
        ),
      ),
      child: Row(
        children: [
          Icon(
            iWon ? Icons.emoji_events_rounded : Icons.remove_circle_outline,
            color: iWon ? winColor : loseColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  iWon ? 'Victory' : 'Defeat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iWon ? winColor : loseColor,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'vs $opponentName',
                  style: TextStyle(color: textPrimary),
                ),
                Text(
                  '${isChallenged ? "You" : opponentName} challenged · '
                  'Str: ${battle['challenger_strength']} vs ${battle['defender_strength']}',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleResultOverlay extends StatelessWidget {
  const _BattleResultOverlay({
    required this.result,
    required this.myId,
    required this.accent,
    required this.onDismiss,
  });

  final Map<String, dynamic> result;
  final String myId;
  final Color accent;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final battleResult = result['result'] as Map<String, dynamic>? ?? {};
    final won = battleResult['challengerWon'] as bool? ?? false;
    final cStr = battleResult['challengerStrength'] as int? ?? 0;
    final dStr = battleResult['defenderStrength'] as int? ?? 0;

    final goldReward = won ? (cStr ~/ 10 + 50) : 10;

    return Container(
      color: Colors.black.withAlpha(180),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: won
                  ? const Color(0xFF7AC97A)
                  : const Color(0xFFE07070),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won
                    ? Icons.emoji_events_rounded
                    : Icons.sports_kabaddi_rounded,
                size: 64,
                color:
                    won ? const Color(0xFFFFD700) : const Color(0xFFE07070),
              ),
              const SizedBox(height: 12),
              Text(
                won ? '⚔️ VICTORY!' : '💀 DEFEAT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                      won ? const Color(0xFFFFD700) : const Color(0xFFE07070),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your strength: $cStr\nOpponent strength: $dStr',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (won)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3020),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$goldReward Gold',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onDismiss,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
