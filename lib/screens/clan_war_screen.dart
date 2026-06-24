import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../services/api_service.dart';

class ClanWarScreen extends StatefulWidget {
  const ClanWarScreen({super.key, required this.text});

  final AppText text;

  @override
  State<ClanWarScreen> createState() => _ClanWarScreenState();
}

class _ClanWarScreenState extends State<ClanWarScreen> {
  Map<String, dynamic>? _warData;
  bool _loading = true;
  bool _contributing = false;
  String? _error;
  String? _successMessage;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _red => const Color(0xFFE05050);
  Color get _green => const Color(0xFF50C878);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.getClanWar();
      if (!mounted) return;
      setState(() {
        _warData = data;
        _loading = false;
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.isOffline ? widget.text.tr('clanWarOffline') : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.text.tr('clanWarOffline');
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final endsAt = _warEndsAt;
    if (endsAt == null) return;
    _updateTimeLeft(endsAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTimeLeft(endsAt);
    });
  }

  void _updateTimeLeft(DateTime endsAt) {
    final diff = endsAt.difference(DateTime.now());
    setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
  }

  DateTime? get _warEndsAt {
    final str = _warData?['war']?['endsAt'] as String?;
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  String _formatDuration(Duration d) {
    if (d.inDays >= 1) {
      final h = d.inHours % 24;
      return '${d.inDays}d ${h.toString().padLeft(2, '0')}h';
    }
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _contribute() async {
    if (_contributing) return;
    setState(() {
      _contributing = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final result = await ApiService.instance.contributeClanWar();
      if (!mounted) return;
      setState(() {
        _successMessage = widget.text
            .tr('clanWarContributed')
            .replaceFirst('{points}', '${result?['pointsAdded'] ?? 0}');
      });
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () =>
            _error = e.isOffline ? widget.text.tr('clanWarOffline') : e.message,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = widget.text.tr('errorUnexpected'));
    } finally {
      if (mounted) setState(() => _contributing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          widget.text.tr('clanWarTitle'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : _error != null && _warData == null
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
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: Text(widget.text.tr('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final war = _warData?['war'];

    if (war == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, size: 56, color: _textSecondary),
              const SizedBox(height: 16),
              Text(
                widget.text.tr('clanWarNoActive'),
                style: TextStyle(color: _textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final clanA = war['clanA'] as Map<String, dynamic>?;
    final clanB = war['clanB'] as Map<String, dynamic>?;
    final myPoints = (_warData?['myPoints'] as num?)?.toInt() ?? 0;
    final canContribute = _warData?['canContribute'] as bool? ?? false;
    final playerStrength = (_warData?['playerStrength'] as num?)?.toInt() ?? 0;
    final leaderboard =
        (_warData?['leaderboard'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final myPlayerId = ApiService.instance.currentPlayerId;
    final playerClanId = war['playerClanId'] as String?;
    final clanAId = clanA?['id'] as String?;

    final myClansPoints = (war['playerClanPoints'] as num?)?.toInt() ?? 0;
    final opponentPoints = (war['opponentClanPoints'] as num?)?.toInt() ?? 0;
    final totalPoints = myClansPoints + opponentPoints;
    final myFraction = totalPoints > 0 ? myClansPoints / totalPoints : 0.5;

    final myClanName = playerClanId == clanAId
        ? (clanA?['name'] as String? ?? '?')
        : (clanB?['name'] as String? ?? '?');
    final opponentName = playerClanId == clanAId
        ? (clanB?['name'] as String? ?? '?')
        : (clanA?['name'] as String? ?? '?');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // War card
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.shield, size: 40, color: _accent),
                const SizedBox(height: 8),
                Text(
                  widget.text.tr('clanWarTitle'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.text.tr("clanWarEndsIn")}: ${_formatDuration(_timeLeft)}',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                // Clan names + scores
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            myClanName,
                            style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '$myClansPoints',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            opponentName,
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '$opponentPoints',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: myFraction,
                    minHeight: 12,
                    backgroundColor: _red.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(_green),
                  ),
                ),
                const SizedBox(height: 16),
                // Player contribution
                Text(
                  '${widget.text.tr("clanWarMyPoints")}: $myPoints',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Contribute button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canContribute && !_contributing
                        ? _contribute
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _textSecondary.withValues(
                        alpha: 0.3,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: _contributing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_circle_outline),
                    label: Text(
                      canContribute
                          ? '${widget.text.tr("clanWarContribute")} (+$playerStrength)'
                          : widget.text.tr('clanWarAlreadyContributed'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                if (!canContribute) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.text.tr('clanWarCooldown'),
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          if (_successMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _successMessage!,
              style: TextStyle(color: _green, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: _red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          // Leaderboard
          if (leaderboard.isNotEmpty) ...[
            Text(
              widget.text.tr('clanWarLeaderboard'),
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
              final clanId = entry['clanId'] as String?;
              final points = (entry['points'] as num?)?.toInt() ?? 0;
              final isMe = entry['playerId'] == myPlayerId;
              final isMyClan = clanId == playerClanId;

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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isMyClan ? _green : _red).withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$points',
                        style: TextStyle(
                          color: isMyClan ? _green : _red,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
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
