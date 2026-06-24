import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_text.dart';
import '../services/api_service.dart';

class AuctionScreen extends StatefulWidget {
  const AuctionScreen({
    super.key,
    required this.text,
    required this.playerGold,
    required this.playerInventory,
    this.onGoldSpent,
  });

  final AppText text;
  final int playerGold;
  final List<Map<String, dynamic>> playerInventory;
  final void Function(int amount)? onGoldSpent;

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);
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
          widget.text.tr('auctionTitle'),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _accent,
          unselectedLabelColor: _textSecondary,
          indicatorColor: _accent,
          tabs: [
            Tab(text: widget.text.tr('auctionBrowse')),
            Tab(text: widget.text.tr('auctionMine')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _BrowseTab(
            text: widget.text,
            playerGold: widget.playerGold,
            onGoldSpent: widget.onGoldSpent,
          ),
          _MyAuctionsTab(
            text: widget.text,
            playerInventory: widget.playerInventory,
            onGoldSpent: widget.onGoldSpent,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ //
//  Browse Tab
// ------------------------------------------------------------------ //

class _BrowseTab extends StatefulWidget {
  const _BrowseTab({
    required this.text,
    required this.playerGold,
    this.onGoldSpent,
  });

  final AppText text;
  final int playerGold;
  final void Function(int amount)? onGoldSpent;

  @override
  State<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends State<_BrowseTab> {
  List<Map<String, dynamic>> _auctions = [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  String _slot = '';
  String _sort = 'ends_asc';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _green => const Color(0xFF50C878);
  Color get _red => const Color(0xFFE05050);
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
      final data = await ApiService.instance.getAuctions(
        slot: _slot.isEmpty ? null : _slot,
        sort: _sort,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _auctions = List<Map<String, dynamic>>.from(
          data['auctions'] as List? ?? [],
        );
        _totalPages = (data['pages'] as num?)?.toInt() ?? 1;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.isOffline ? widget.text.tr('auctionOffline') : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.text.tr('auctionOffline');
      });
    }
  }

  Future<void> _placeBid(Map<String, dynamic> auction) async {
    final minBid = ((auction['currentBid'] as num?)?.toInt() ?? 0) + 1;
    final effectiveMin = [
      minBid,
      (auction['minPrice'] as num?)?.toInt() ?? 1,
    ].reduce((a, b) => a > b ? a : b);

    final controller = TextEditingController(text: '$effectiveMin');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.text.tr('auctionBidTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.text.tr("auctionItem")}: ${(auction["item"] as Map?)?["name"] ?? "?"}',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.text.tr("auctionMinBid")}: $effectiveMin',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: widget.text.tr('auctionBidAmount'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.text.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(widget.text.tr('auctionPlaceBid')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final amount = int.tryParse(controller.text.trim());
    if (amount == null || amount < effectiveMin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.text.tr("auctionMinBid")}: $effectiveMin'),
          ),
        );
      }
      return;
    }

    try {
      await ApiService.instance.placeBid(auction['id'] as String, amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.text.tr('auctionBidPlaced'))),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _buyNow(Map<String, dynamic> auction) async {
    final price = (auction['buyNowPrice'] as num?)?.toInt() ?? 0;
    if (widget.playerGold < price) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.text.tr('notEnoughGold'))));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.text.tr('auctionBuyNowTitle')),
        content: Text(
          '${widget.text.tr("auctionBuyNowConfirm")}\n\n'
          '${(auction["item"] as Map?)?["name"] ?? "?"}\n'
          '${widget.text.tr("gold")}: $price',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.text.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            child: Text(widget.text.tr('auctionBuyNow')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.instance.buyNowAuction(auction['id'] as String);
      if (!mounted) return;
      widget.onGoldSpent?.call(price);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.text.tr('auctionBought'))));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _slot.isEmpty ? '' : _slot,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(widget.text.tr('auctionAllSlots')),
                    ),
                    ...[
                      'weapon',
                      'armor',
                      'helm',
                      'gloves',
                      'boots',
                      'ring',
                    ].map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          widget.text.tr(
                            'slot${s[0].toUpperCase()}${s.substring(1)}',
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _slot = v ?? '';
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _sort,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'ends_asc',
                      child: Text(widget.text.tr('auctionSortEndsAsc')),
                    ),
                    DropdownMenuItem(
                      value: 'ends_desc',
                      child: Text(widget.text.tr('auctionSortEndsDesc')),
                    ),
                    DropdownMenuItem(
                      value: 'price_asc',
                      child: Text(widget.text.tr('auctionSortPriceAsc')),
                    ),
                    DropdownMenuItem(
                      value: 'price_desc',
                      child: Text(widget.text.tr('auctionSortPriceDesc')),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _sort = v ?? 'ends_asc';
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _accent))
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: TextStyle(color: _textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _load,
                        child: Text(widget.text.tr('retry')),
                      ),
                    ],
                  ),
                )
              : _auctions.isEmpty
              ? Center(
                  child: Text(
                    widget.text.tr('auctionEmpty'),
                    style: TextStyle(color: _textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _auctions.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _auctions.length) {
                      return _PaginationRow(
                        page: _page,
                        totalPages: _totalPages,
                        onPrev: _page > 1
                            ? () {
                                setState(() => _page--);
                                _load();
                              }
                            : null,
                        onNext: _page < _totalPages
                            ? () {
                                setState(() => _page++);
                                _load();
                              }
                            : null,
                      );
                    }
                    final a = _auctions[i];
                    final myUsername = ApiService.instance.currentUsername;
                    final isOwn = (a['sellerName'] as String?) == myUsername;
                    return _AuctionCard(
                      auction: a,
                      text: widget.text,
                      cardBg: _cardBg,
                      accent: _accent,
                      green: _green,
                      red: _red,
                      textPrimary: _textPrimary,
                      textSecondary: _textSecondary,
                      playerGold: widget.playerGold,
                      isOwn: isOwn,
                      onBid: isOwn ? null : () => _placeBid(a),
                      onBuyNow: (isOwn || a['buyNowPrice'] == null)
                          ? null
                          : () => _buyNow(a),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ //
//  My Auctions Tab
// ------------------------------------------------------------------ //

class _MyAuctionsTab extends StatefulWidget {
  const _MyAuctionsTab({
    required this.text,
    required this.playerInventory,
    this.onGoldSpent,
  });

  final AppText text;
  final List<Map<String, dynamic>> playerInventory;
  final void Function(int amount)? onGoldSpent;

  @override
  State<_MyAuctionsTab> createState() => _MyAuctionsTabState();
}

class _MyAuctionsTabState extends State<_MyAuctionsTab> {
  List<Map<String, dynamic>> _selling = [];
  List<Map<String, dynamic>> _won = [];
  bool _loading = true;
  String? _error;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);
  Color get _accent => const Color(0xFFD4A84B);
  Color get _green => const Color(0xFF50C878);
  Color get _red => const Color(0xFFE05050);
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
      final data = await ApiService.instance.getMyAuctions();
      if (!mounted) return;
      setState(() {
        _selling = List<Map<String, dynamic>>.from(
          data?['selling'] as List? ?? [],
        );
        _won = List<Map<String, dynamic>>.from(data?['won'] as List? ?? []);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.isOffline ? widget.text.tr('auctionOffline') : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.text.tr('auctionOffline');
      });
    }
  }

  Future<void> _claimWon(Map<String, dynamic> auction) async {
    try {
      final result = await ApiService.instance.claimAuction(
        auction['id'] as String,
      );
      if (!mounted) return;
      if (result != null) {
        widget.onGoldSpent?.call((result['goldPaid'] as num?)?.toInt() ?? 0);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.text.tr('auctionClaimed'))));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancelAuction(Map<String, dynamic> auction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.text.tr('auctionCancelTitle')),
        content: Text(widget.text.tr('auctionCancelConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.text.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: Text(widget.text.tr('auctionCancel')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.instance.cancelAuction(auction['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.text.tr('auctionCancelled'))),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _listItem() async {
    final unlisted = widget.playerInventory
        .where(
          (i) =>
              !(i['isLocked'] as bool? ?? false) &&
              !(i['isEquipped'] as bool? ?? false),
        )
        .toList();

    if (unlisted.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.text.tr('auctionNoItems'))));
      return;
    }

    Map<String, dynamic>? selectedItem;
    final minPriceCtrl = TextEditingController(text: '100');
    final buyNowCtrl = TextEditingController();
    String duration = '24';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(widget.text.tr('auctionListItem')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<Map<String, dynamic>>(
                  isExpanded: true,
                  hint: Text(widget.text.tr('auctionSelectItem')),
                  value: selectedItem,
                  items: unlisted.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(
                        '${item["name"] ?? "?"} (${item["tier"] ?? "?"}, ${item["power"] ?? 0})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setDlgState(() => selectedItem = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: widget.text.tr('auctionMinPrice'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: buyNowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        '${widget.text.tr("auctionBuyNowPrice")} (${widget.text.tr("auctionOptional")})',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.text.tr('auctionDuration'),
                  style: const TextStyle(fontSize: 12),
                ),
                DropdownButton<String>(
                  value: duration,
                  isExpanded: true,
                  items: ['1', '6', '12', '24', '48', '72'].map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text('$h ${widget.text.tr("auctionHours")}'),
                    );
                  }).toList(),
                  onChanged: (v) => setDlgState(() => duration = v ?? '24'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(widget.text.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: selectedItem != null
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(widget.text.tr('auctionList')),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedItem == null || !mounted) return;

    final minPrice = int.tryParse(minPriceCtrl.text.trim()) ?? 0;
    final buyNow = buyNowCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(buyNowCtrl.text.trim());
    final durationHours = int.tryParse(duration) ?? 24;

    try {
      await ApiService.instance.createAuction(
        itemId: selectedItem!['id'] as String,
        minPrice: minPrice,
        buyNowPrice: buyNow,
        durationHours: durationHours,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.text.tr('auctionListed'))));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? Center(child: CircularProgressIndicator(color: _accent))
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: TextStyle(color: _textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _load,
                  child: Text(widget.text.tr('retry')),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // List new item button
              ElevatedButton.icon(
                onPressed: _listItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.add),
                label: Text(widget.text.tr('auctionListItem')),
              ),
              const SizedBox(height: 16),
              // Won auctions to claim
              if (_won.isNotEmpty) ...[
                Text(
                  widget.text.tr('auctionWon'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _green,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ..._won.map(
                  (a) => _WonAuctionCard(
                    auction: a,
                    text: widget.text,
                    cardBg: _cardBg,
                    accent: _accent,
                    green: _green,
                    textPrimary: _textPrimary,
                    textSecondary: _textSecondary,
                    onClaim: () => _claimWon(a),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // My active listings
              Text(
                widget.text.tr('auctionMyListings'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              if (_selling.isEmpty)
                Text(
                  widget.text.tr('auctionNoListings'),
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                )
              else
                ..._selling.map(
                  (a) => _MyListingCard(
                    auction: a,
                    text: widget.text,
                    cardBg: _cardBg,
                    accent: _accent,
                    green: _green,
                    red: _red,
                    textPrimary: _textPrimary,
                    textSecondary: _textSecondary,
                    onCancel:
                        (a['status'] == 'active' &&
                            a['highestBidderId'] == null)
                        ? () => _cancelAuction(a)
                        : null,
                  ),
                ),
            ],
          );
  }
}

// ------------------------------------------------------------------ //
//  Reusable card widgets
// ------------------------------------------------------------------ //

class _AuctionCard extends StatelessWidget {
  const _AuctionCard({
    required this.auction,
    required this.text,
    required this.cardBg,
    required this.accent,
    required this.green,
    required this.red,
    required this.textPrimary,
    required this.textSecondary,
    required this.playerGold,
    required this.isOwn,
    this.onBid,
    this.onBuyNow,
  });

  final Map<String, dynamic> auction;
  final AppText text;
  final Color cardBg, accent, green, red, textPrimary, textSecondary;
  final int playerGold;
  final bool isOwn;
  final VoidCallback? onBid;
  final VoidCallback? onBuyNow;

  String _timeLeft(String? endsAtStr) {
    if (endsAtStr == null) return '?';
    final ends = DateTime.tryParse(endsAtStr);
    if (ends == null) return '?';
    final diff = ends.difference(DateTime.now());
    if (diff.isNegative) return text.tr('auctionExpired');
    if (diff.inDays >= 1) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final item = auction['item'] as Map<String, dynamic>?;
    final currentBid = (auction['currentBid'] as num?)?.toInt() ?? 0;
    final minPrice = (auction['minPrice'] as num?)?.toInt() ?? 0;
    final buyNow = (auction['buyNowPrice'] as num?)?.toInt();
    final displayPrice = currentBid > 0 ? currentBid : minPrice;
    final tier = item?['tier'] as String? ?? 'common';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?['name'] as String? ?? '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _tierColor(tier),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${item?['slot'] ?? "?"} · ${item?['tier'] ?? "?"} · ⚡${item?['power'] ?? 0}',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${currentBid > 0 ? text.tr("auctionCurrentBid") : text.tr("auctionStartingBid")}: $displayPrice',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (buyNow != null)
                    Text(
                      '${text.tr("auctionBuyNow")}: $buyNow',
                      style: TextStyle(color: green, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 12, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                _timeLeft(auction['endsAt'] as String?),
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${text.tr("auctionSeller")}: ${auction["sellerName"] ?? "?"}',
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          if (!isOwn) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBid,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      text.tr('auctionBid'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                if (buyNow != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: playerGold >= buyNow ? onBuyNow : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        text.tr('auctionBuyNow'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'legendary':
        return const Color(0xFFFFAA00);
      case 'epic':
        return const Color(0xFFAA44FF);
      case 'rare':
        return const Color(0xFF4488FF);
      case 'uncommon':
        return const Color(0xFF44BB44);
      default:
        return const Color(0xFFBBBBBB);
    }
  }
}

class _WonAuctionCard extends StatelessWidget {
  const _WonAuctionCard({
    required this.auction,
    required this.text,
    required this.cardBg,
    required this.accent,
    required this.green,
    required this.textPrimary,
    required this.textSecondary,
    required this.onClaim,
  });

  final Map<String, dynamic> auction;
  final AppText text;
  final Color cardBg, accent, green, textPrimary, textSecondary;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final item = auction['item'] as Map<String, dynamic>?;
    final finalPrice = (auction['finalPrice'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: green.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?['name'] as String? ?? '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${text.tr("gold")}: $finalPrice',
                  style: TextStyle(color: green, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onClaim,
            style: ElevatedButton.styleFrom(
              backgroundColor: green,
              foregroundColor: Colors.white,
            ),
            child: Text(text.tr('auctionClaim')),
          ),
        ],
      ),
    );
  }
}

class _MyListingCard extends StatelessWidget {
  const _MyListingCard({
    required this.auction,
    required this.text,
    required this.cardBg,
    required this.accent,
    required this.green,
    required this.red,
    required this.textPrimary,
    required this.textSecondary,
    this.onCancel,
  });

  final Map<String, dynamic> auction;
  final AppText text;
  final Color cardBg, accent, green, red, textPrimary, textSecondary;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final item = auction['item'] as Map<String, dynamic>?;
    final currentBid = (auction['currentBid'] as num?)?.toInt() ?? 0;
    final status = auction['status'] as String? ?? 'active';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'sold':
        statusColor = green;
        statusLabel = text.tr('auctionStatusSold');
        break;
      case 'expired':
        statusColor = red;
        statusLabel = text.tr('auctionStatusExpired');
        break;
      case 'cancelled':
        statusColor = textSecondary;
        statusLabel = text.tr('auctionStatusCancelled');
        break;
      default:
        statusColor = accent;
        statusLabel = text.tr('auctionStatusActive');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?['name'] as String? ?? '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontSize: 14,
                  ),
                ),
                if (currentBid > 0)
                  Text(
                    '${text.tr("auctionCurrentBid")}: $currentBid',
                    style: TextStyle(color: accent, fontSize: 12),
                  ),
                Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              child: Text(
                text.tr('auctionCancel'),
                style: TextStyle(color: red),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({
    required this.page,
    required this.totalPages,
    this.onPrev,
    this.onNext,
  });

  final int page, totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Text('$page / $totalPages'),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}
