import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../services/api_service.dart';

class WorldBossScreen extends StatefulWidget {
  const WorldBossScreen({
    super.key,
    required this.text,
    required this.playerStrength,
  });

  final AppText text;
  final int playerStrength;

  @override
  State<WorldBossScreen> createState() => _WorldBossScreenState();
}

class _WorldBossScreenState extends State<WorldBossScreen> {
  Map<String, dynamic>? _bossData;
  bool _loading = true;
  bool _attacking = false;
  String? _error;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _red => const Color(0xFFE05050);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    _loadBoss();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoss() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.getWorldBoss();
      if (!mounted) return;
      setState(() {
        _bossData = data;
        _loading = false;
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.isOffline ? widget.text.tr('worldBossOffline') : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.text.tr('worldBossOffline');
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final bossEndsAt = _bossEndsAt;
    if (bossEndsAt == null) return;

    _updateTimeLeft(bossEndsAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTimeLeft(bossEndsAt);
    });
  }

  void _updateTimeLeft(DateTime endsAt) {
    final diff = endsAt.difference(DateTime.now());
    setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
  }

  DateTime? get _bossEndsAt {
    final endsAtStr = _bossData?['boss']?['endsAt'] as String?;
    if (endsAtStr == null) return null;
    return DateTime.tryParse(endsAtStr);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _attack() async {
    if (_attacking || _bossData == null) return;
    final boss = _bossData!['boss'] as Map<String, dynamic>?;
    if (boss == null || boss['status'] != 'active') return;

    setState(() {
      _attacking = true;
      _error = null;
    });

    // Damage based on player strength (1-10% of strength, with randomness)
    final base = (widget.playerStrength * 0.05).round().clamp(100, 500000);

    try {
      final result = await ApiService.instance.attackWorldBoss(base);
      if (!mounted) return;
      if (result != null) {
        // Update local boss data
        final updatedBoss = Map<String, dynamic>.from(
          _bossData!['boss'] as Map<String, dynamic>,
        );
        updatedBoss['currentHp'] = result['newHp'];
        updatedBoss['status'] = result['status'];
        setState(() {
          _bossData = {
            ..._bossData!,
            'boss': updatedBoss,
            'playerDamage':
                (_bossData!['playerDamage'] as int? ?? 0) +
                (result['damageDealt'] as int? ?? 0),
          };
        });
        if (result['defeated'] == true) {
          _loadBoss(); // Refresh to get new boss
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.isOffline
            ? widget.text.tr('worldBossOffline')
            : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = widget.text.tr('errorUnexpected'));
    } finally {
      if (mounted) setState(() => _attacking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          text.tr('worldBossTitle'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _loadBoss,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
          ? _buildError()
          : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: _textSecondary),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: _textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBoss,
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: Text(widget.text.tr('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final boss = _bossData?['boss'] as Map<String, dynamic>?;
    if (boss == null) {
      return Center(
        child: Text(
          widget.text.tr('worldBossNoActive'),
          style: TextStyle(color: _textSecondary),
        ),
      );
    }

    final maxHp = (boss['maxHp'] as num?)?.toInt() ?? 1;
    final currentHp = (boss['currentHp'] as num?)?.toInt() ?? 0;
    final status = boss['status'] as String? ?? 'active';
    final hpFraction = (currentHp / maxHp).clamp(0.0, 1.0);
    final playerDamage = (_bossData?['playerDamage'] as num?)?.toInt() ?? 0;
    final leaderboard =
        (_bossData?['leaderboard'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final isDefeated = status == 'defeated';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Boss card
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Boss icon + name
                Icon(
                  Icons.whatshot,
                  size: 56,
                  color: isDefeated ? _textSecondary : _red,
                ),
                const SizedBox(height: 8),
                Text(
                  boss['name'] as String? ?? 'Boss',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (isDefeated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _textSecondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.text.tr('worldBossDefeated'),
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  )
                else
                  Text(
                    '${widget.text.tr("worldBossEndsIn")}: ${_formatDuration(_timeLeft)}',
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                const SizedBox(height: 16),
                // HP bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.text.tr('worldBossHp'),
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                        Text(
                          '$currentHp / $maxHp',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: hpFraction,
                        minHeight: 14,
                        backgroundColor: _red.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(_red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Player damage contribution
                if (playerDamage > 0)
                  Text(
                    '${widget.text.tr("worldBossYourDmg")}: $playerDamage',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 12),
                // Attack button
                if (!isDefeated)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _attacking ? null : _attack,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _attacking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.flash_on),
                      label: Text(
                        _attacking
                            ? widget.text.tr('worldBossAttacking')
                            : widget.text.tr('worldBossAttack'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: _red, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          // Leaderboard
          if (leaderboard.isNotEmpty) ...[
            Text(
              widget.text.tr('worldBossLeaderboard'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...leaderboard.map((entry) {
              final rank = entry['rank'] as int? ?? 0;
              final username = entry['username'] as String? ?? '?';
              final damage = (entry['damage'] as num?)?.toInt() ?? 0;
              final isMe = username == ApiService.instance.currentUsername;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isMe ? _accent.withValues(alpha: 0.15) : _cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isMe ? _accent.withValues(alpha: 0.5) : _cardBg,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          color: rank <= 3 ? _accent : _textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        isMe
                            ? '${widget.text.tr("you")} ($username)'
                            : username,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: isMe
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      damage.toString(),
                      style: TextStyle(
                        color: _red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
