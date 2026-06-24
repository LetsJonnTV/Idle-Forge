import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../services/api_service.dart';

/// List screen showing all active events, navigates to EventShopScreen on tap.
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
                      style: ElevatedButton.styleFrom(backgroundColor: _accent),
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
                final colorHex = event['bannerColor'] as String? ?? '#D4A84B';
                final color = EventBannerWidget._hexColor(colorHex);
                final endsAt = EventBannerWidget._parseDate(
                  event['endsAt'] as String?,
                );
                final timeLeft = endsAt != null
                    ? endsAt.difference(DateTime.now())
                    : Duration.zero;
                return GestureDetector(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EventShopScreen(event: event, text: widget.text),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
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
                            Icons.celebration,
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
                                  '${widget.text.tr("eventsEndsIn")}: ${EventBannerWidget._formatDuration(timeLeft)}',
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

/// Banner widget shown on main screen when events are active.
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
    // Show first active event as banner
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
            const Icon(Icons.celebration, color: Colors.white, size: 22),
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

  static Color _hexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFD4A84B);
    }
  }

  static DateTime? _parseDate(String? s) {
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }
}

/// Full event shop screen for a single event.
class EventShopScreen extends StatefulWidget {
  const EventShopScreen({super.key, required this.event, required this.text});

  final Map<String, dynamic> event;
  final AppText text;

  @override
  State<EventShopScreen> createState() => _EventShopScreenState();
}

class _EventShopScreenState extends State<EventShopScreen> {
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
    return EventBannerWidget._hexColor(hex);
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
      final result = await ApiService.instance.buyEventItem(
        _eventId,
        item['id'] as String,
      );
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _playerCurrency = (result['remainingCurrency'] as num?)?.toInt() ?? 0;
          _successMessage = widget.text.tr('eventsShopBought');
          // Mark item as purchased
          final idx = _items.indexWhere((i) => i['id'] == item['id']);
          if (idx >= 0) {
            _items[idx] = {..._items[idx], 'purchased': true};
          }
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.isOffline
            ? widget.text.tr('eventsOffline')
            : (e.message.isNotEmpty
                  ? e.message
                  : widget.text.tr('errorUnexpected')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = widget.text.tr('errorUnexpected'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventName =
        widget.event['name'] as String? ?? widget.text.tr('eventsShopTitle');
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          eventName,
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textSecondary),
            onPressed: _loadShop,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _accent))
          : Column(
              children: [
                // Currency header
                Container(
                  width: double.infinity,
                  color: _accent.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFE05050),
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
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
                          itemBuilder: (context, index) =>
                              _buildItem(_items[index]),
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
                    style: TextStyle(color: _textSecondary, fontSize: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
