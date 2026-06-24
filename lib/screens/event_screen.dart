import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../services/api_service.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Color _hexColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return const Color(0xFFD4A84B);
  }
}

DateTime? _parseDate(String? s) {
  if (s == null) return null;
  return DateTime.tryParse(s);
}

String _formatDuration(Duration d) {
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  return '${h}h ${m}m';
}

String _fmtShort(Duration d) {
  if (d.inDays > 0) return '${d.inDays}T ${d.inHours % 24}H';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '${h}H ${m}M';
  return '${m}M';
}

IconData _eventTypeIcon(String type) {
  return switch (type) {
    'world_boss'       => Icons.whatshot,
    'forge_tournament' => Icons.emoji_events,
    'dungeon_rush'     => Icons.bolt,
    'trade_expedition' => Icons.swap_horiz,
    _                  => Icons.celebration,
  };
}

String _eventTypeLabel(String type, AppText text) {
  return switch (type) {
    'world_boss'       => text.tr('eventTypeWorldBoss'),
    'forge_tournament' => text.tr('eventTypeForgeTournament'),
    'dungeon_rush'     => text.tr('eventTypeDungeonRush'),
    'trade_expedition' => text.tr('eventTypeTradeExpedition'),
    _                  => text.tr('eventTypeCollection'),
  };
}

String _eventScoreHint(String type, AppText text) {
  return switch (type) {
    'world_boss'       => text.tr('eventScoreHintWorldBoss'),
    'forge_tournament' => text.tr('eventScoreHintForgeTournament'),
    'dungeon_rush'     => text.tr('eventScoreHintDungeonRush'),
    'trade_expedition' => text.tr('eventScoreHintTradeExpedition'),
    _                  => text.tr('eventScoreHintCollection'),
  };
}

// ---------------------------------------------------------------------------
// EventFloatingButton — animated pill on the right side of the main screen
// ---------------------------------------------------------------------------

class EventFloatingButton extends StatefulWidget {
  const EventFloatingButton({
    super.key,
    required this.events,
    required this.text,
    required this.onTap,
  });

  final List<Map<String, dynamic>> events;
  final AppText text;
  final void Function(Map<String, dynamic> event) onTap;

  @override
  State<EventFloatingButton> createState() => _EventFloatingButtonState();
}

class _EventFloatingButtonState extends State<EventFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scaleAnim;
  late final Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return const SizedBox.shrink();
    final event = widget.events.first;
    final colorHex = event['bannerColor'] as String? ?? '#D4A84B';
    final color = _hexColor(colorHex);
    final endsAt = _parseDate(event['endsAt'] as String?);
    final timeLeft = endsAt != null ? endsAt.difference(_now) : Duration.zero;
    final countdown = timeLeft.isNegative ? '' : _fmtShort(timeLeft);
    final eventType = event['eventType'] as String? ?? 'collection';

    return GestureDetector(
      onTap: () => widget.onTap(event),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 42,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.75)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_eventTypeIcon(eventType), color: Colors.white, size: 20),
              if (countdown.isNotEmpty) ...[
                const SizedBox(height: 6),
                RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    countdown,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EventDetailScreen — fullscreen event page with 3 tabs
// ---------------------------------------------------------------------------

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    required this.text,
  });

  final Map<String, dynamic> event;
  final AppText text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
    final textPrimary =
        isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
    final textSecondary =
        isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);
    final colorHex = event['bannerColor'] as String? ?? '#D4A84B';
    final accent = _hexColor(colorHex);
    final eventName = event['name'] as String? ?? text.tr('eventsTitle');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            eventName,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: textSecondary,
            tabs: [
              Tab(text: text.tr('eventTabPlay')),
              Tab(text: text.tr('eventTabShop')),
              Tab(text: text.tr('eventTabLeaderboard')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PlayTab(event: event, text: text),
            _ShopTabBody(event: event, text: text),
            _LeaderboardTab(event: event, text: text),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PlayTab — shows event type, score hint, player score
// ---------------------------------------------------------------------------

class _PlayTab extends StatelessWidget {
  const _PlayTab({required this.event, required this.text});

  final Map<String, dynamic> event;
  final AppText text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
    final cardBg = isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
    final textPrimary =
        isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
    final textSecondary =
        isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);
    final colorHex = event['bannerColor'] as String? ?? '#D4A84B';
    final accent = _hexColor(colorHex);
    final eventType = event['eventType'] as String? ?? 'collection';
    final playerScore = (event['playerScore'] as num?)?.toInt() ?? 0;
    final endsAt = _parseDate(event['endsAt'] as String?);
    final timeLeft = endsAt != null
        ? endsAt.difference(DateTime.now())
        : Duration.zero;

    return Container(
      color: bg,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Event type badge row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_eventTypeIcon(eventType), color: accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _eventTypeLabel(eventType, text),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!timeLeft.isNegative) ...[
                const SizedBox(width: 10),
                Text(
                  '${text.tr("eventsEndsIn")}: ${_formatDuration(timeLeft)}',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Scoring hint card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _eventScoreHint(eventType, text),
                    style: TextStyle(color: textPrimary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Player score card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text.tr('eventYourScore'),
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$playerScore',
                  style: TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ShopTabBody — embeddable shop (no Scaffold)
// ---------------------------------------------------------------------------

class _ShopTabBody extends StatefulWidget {
  const _ShopTabBody({required this.event, required this.text});

  final Map<String, dynamic> event;
  final AppText text;

  @override
  State<_ShopTabBody> createState() => _ShopTabBodyState();
}

class _ShopTabBodyState extends State<_ShopTabBody> {
  List<Map<String, dynamic>> _items = [];
  int _playerCurrency = 0;
  bool _loading = true;
  String? _error;
  String? _successMessage;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);
  Color get _accent {
    final hex = widget.event['bannerColor'] as String? ?? '#D4A84B';
    return _hexColor(hex);
  }

  String get _eventId => widget.event['id'] as String? ?? '';
  String get _currencyName =>
      widget.event['currencyName'] as String? ??
      widget.text.tr('eventsCurrency');

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.getEventShop(_eventId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = (data?['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _playerCurrency = (data?['playerCurrency'] as num?)?.toInt() ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            e.isOffline ? widget.text.tr('eventsOffline') : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.text.tr('eventsOffline');
      });
    }
  }

  Future<void> _buy(Map<String, dynamic> item) async {
    final cost = (item['currency_cost'] as num?)?.toInt() ?? 0;
    if (_playerCurrency < cost) {
      setState(() => _error = widget.text.tr('eventsShopNotEnough'));
      return;
    }
    setState(() {
      _error = null;
      _successMessage = null;
    });
    try {
      final result = await ApiService.instance
          .buyEventItem(_eventId, item['id'] as String);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _playerCurrency =
              (result['remainingCurrency'] as num?)?.toInt() ?? 0;
          _successMessage = widget.text.tr('eventsShopBought');
          final idx = _items.indexWhere((i) => i['id'] == item['id']);
          if (idx >= 0) {
            _items[idx] = {..._items[idx], 'purchased': true};
          }
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isOffline
          ? widget.text.tr('eventsOffline')
          : (e.message.isNotEmpty
                ? e.message
                : widget.text.tr('errorUnexpected')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = widget.text.tr('errorUnexpected'));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: _bg,
        child: Center(child: CircularProgressIndicator(color: _accent)),
      );
    }
    return Container(
      color: _bg,
      child: Column(
        children: [
          // currency header
          Container(
            width: double.infinity,
            color: _accent.withValues(alpha: 0.1),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: _accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$_playerCurrency $_currencyName',
                  style: TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: _textSecondary, size: 18),
                  onPressed: _loadShop,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _error!,
                style:
                    const TextStyle(color: Color(0xFFE05050), fontSize: 13),
              ),
            ),
          if (_successMessage != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _successMessage!,
                style: TextStyle(color: _accent, fontSize: 13),
              ),
            ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      widget.text.tr('eventsNoActive'),
                      style: TextStyle(color: _textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildItem(_items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '?';
    final description = item['description'] as String? ?? '';
    final cost = (item['currency_cost'] as num?)?.toInt() ?? 0;
    final purchased = item['purchased'] as bool? ?? false;
    final canAfford = _playerCurrency >= cost;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: purchased ? _accent.withValues(alpha: 0.4) : _cardBg,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.card_giftcard, color: _accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style:
                        TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.monetization_on, color: _accent, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      '$cost $_currencyName',
                      style: TextStyle(
                        color: canAfford ? _accent : _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (purchased)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.text.tr('eventsShopOwned'),
                style: TextStyle(
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: canAfford ? () => _buy(item) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.text.tr('eventsShopBuy'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LeaderboardTab — fetches and shows event leaderboard
// ---------------------------------------------------------------------------

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab({required this.event, required this.text});

  final Map<String, dynamic> event;
  final AppText text;

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _playerRank;
  bool _loading = true;
  String? _error;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);
  Color get _accent {
    final hex = widget.event['bannerColor'] as String? ?? '#D4A84B';
    return _hexColor(hex);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final eventId = widget.event['id'] as String? ?? '';
    try {
      final data = await ApiService.instance.getEventLeaderboard(eventId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _entries = (data?['leaderboard'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _playerRank = data?['playerRank'] as Map<String, dynamic>?;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.text.tr('eventsOffline');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: Column(
        children: [
          // Player's own rank strip
          if (_playerRank != null)
            Container(
              width: double.infinity,
              color: _accent.withValues(alpha: 0.1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.star, color: _accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.text.tr("eventYourRank")}: #${_playerRank!["rank"]}',
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_playerRank!["score"]}',
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh, color: _textSecondary, size: 18),
                    onPressed: _load,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style:
                    const TextStyle(color: Color(0xFFE05050), fontSize: 13),
              ),
            ),
          if (_loading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _accent),
              ),
            )
          else if (_entries.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.text.tr('eventLeaderboardEmpty'),
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: _entries.length,
                itemBuilder: (ctx, i) {
                  final entry = _entries[i];
                  final rank = (entry['rank'] as num?)?.toInt() ?? (i + 1);
                  final username = entry['username'] as String? ?? '?';
                  final score = (entry['score'] as num?)?.toInt() ?? 0;
                  final isMe = entry['isMe'] as bool? ?? false;

                  Color rankColor = _textSecondary;
                  if (rank == 1) rankColor = const Color(0xFFFFD700);
                  if (rank == 2) rankColor = const Color(0xFFC0C0C0);
                  if (rank == 3) rankColor = const Color(0xFFCD7F32);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? _accent.withValues(alpha: 0.12)
                          : _cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isMe
                            ? _accent.withValues(alpha: 0.4)
                            : _cardBg,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              color: rankColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            isMe
                                ? '$username ${widget.text.tr("eventLeaderboardYou")}'
                                : username,
                            style: TextStyle(
                              color: isMe ? _accent : _textPrimary,
                              fontWeight: isMe
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '$score',
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EventsListScreen — standalone list (kept for backward compat)
// ---------------------------------------------------------------------------

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key, required this.text});

  final AppText text;

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFFB5B5B5) : const Color(0xFF555555);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await ApiService.instance.getActiveEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.isOffline ? widget.text.tr('eventsOffline') : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.text.tr('eventsOffline');
      });
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
          widget.text.tr('eventsTitle'),
          style:
              TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
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
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 48, color: _textSecondary),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: _textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                      ),
                      child: Text(widget.text.tr('retry')),
                    ),
                  ],
                ),
              ),
            )
          : _events.isEmpty
          ? Center(
              child: Text(
                widget.text.tr('eventsNoActive'),
                style: TextStyle(color: _textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final event = _events[i];
                final colorHex =
                    event['bannerColor'] as String? ?? '#D4A84B';
                final color = _hexColor(colorHex);
                final endsAt = _parseDate(event['endsAt'] as String?);
                final timeLeft = endsAt != null
                    ? endsAt.difference(DateTime.now())
                    : Duration.zero;
                return GestureDetector(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(
                        event: event,
                        text: widget.text,
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                      ),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _eventTypeIcon(
                              event['eventType'] as String? ?? 'collection',
                            ),
                            color: color,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event['name'] as String? ?? '?',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (!timeLeft.isNegative)
                                Text(
                                  '${widget.text.tr("eventsEndsIn")}: ${_formatDuration(timeLeft)}',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${event['playerCurrency'] ?? 0}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              event['currencyName'] as String? ??
                                  widget.text.tr('eventsCurrency'),
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: _textSecondary),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// EventBannerWidget — horizontal banner for embedding in other screens
// ---------------------------------------------------------------------------

class EventBannerWidget extends StatelessWidget {
  const EventBannerWidget({
    super.key,
    required this.events,
    required this.text,
    required this.onTap,
  });

  final List<Map<String, dynamic>> events;
  final AppText text;
  final void Function(Map<String, dynamic> event) onTap;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final event = events.first;
    final colorHex = event['bannerColor'] as String? ?? '#D4A84B';
    final color = _hexColor(colorHex);
    final endsAt = _parseDate(event['endsAt'] as String?);
    final timeLeft = endsAt != null
        ? endsAt.difference(DateTime.now())
        : Duration.zero;

    return GestureDetector(
      onTap: () => onTap(event),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.85),
              color.withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              _eventTypeIcon(
                event['eventType'] as String? ?? 'collection',
              ),
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['name'] as String? ?? text.tr('eventsTitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (!timeLeft.isNegative)
                    Text(
                      '${text.tr("eventsEndsIn")}: ${_formatDuration(timeLeft)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${event['playerCurrency'] ?? 0} ${text.tr("eventsCurrency")}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  // kept for backward compat (used by event_screen internally and by main.dart)
  static Color hexColor(String hex) => _hexColor(hex);
  static DateTime? parseDate(String? s) => _parseDate(s);
  static String formatDuration(Duration d) => _formatDuration(d);
}

// ---------------------------------------------------------------------------
// EventShopScreen — standalone shop screen (kept for backward compat)
// ---------------------------------------------------------------------------

class EventShopScreen extends StatelessWidget {
  const EventShopScreen({super.key, required this.event, required this.text});

  final Map<String, dynamic> event;
  final AppText text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
    final textPrimary =
        isDark ? const Color(0xFFE2E2E2) : const Color(0xFF1A1A1A);
    final eventName = event['name'] as String? ?? text.tr('eventsShopTitle');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          eventName,
          style:
              TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _ShopTabBody(event: event, text: text),
    );
  }
}
