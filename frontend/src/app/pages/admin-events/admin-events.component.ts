import { Component, OnInit } from '@angular/core';

import { ApiService } from '../../core/api.service';

interface AdminEvent {
  id: string;
  name: string;
  description: string;
  starts_at: string;
  ends_at: string;
  currency_name: string;
  banner_color: string;
  item_count: number;
  total_currency_distributed: number;
  status: 'active' | 'upcoming' | 'expired';
  event_type: string;
  type_config: Record<string, unknown>;
  notify_on_start: boolean;
}

interface ShopItem {
  id: string;
  name: string;
  description: string;
  icon: string;
  currency_cost: number;
  max_per_player: number;
  sort_order: number;
  purchase_count: number;
}

interface RankReward {
  id: string;
  rank_from: number;
  rank_to: number;
  reward_type: 'gold' | 'item';
  amount: number | null;
  item_id: string | null;
  leaderboard_type: string;
}

@Component({
  selector: 'app-admin-events',
  templateUrl: './admin-events.component.html',
  styleUrls: ['./admin-events.component.scss']
})
export class AdminEventsComponent implements OnInit {
  readonly EVENT_TYPES = [
    { value: 'collection',        label: 'Sammlung' },
    { value: 'world_boss',        label: 'World Boss' },
    { value: 'forge_tournament',  label: 'Schmiede-Turnier' },
    { value: 'dungeon_rush',      label: 'Dungeon Rush' },
    { value: 'trade_expedition',  label: 'Handels-Expedition' },
  ];

  readonly EVENT_TYPE_CONFIGS: Record<string, Array<{ key: string; label: string; type: 'text' | 'number' }>> = {
    collection: [
      { key: 'target_item_category',  label: 'Ziel-Kategorie',     type: 'text'   },
      { key: 'bonus_drop_multiplier', label: 'Bonus Multiplikator', type: 'number' },
    ],
    world_boss: [
      { key: 'boss_name',              label: 'Boss Name',             type: 'text'   },
      { key: 'hp',                     label: 'HP',                    type: 'number' },
      { key: 'max_attacks_per_player', label: 'Max Angriffe/Spieler',  type: 'number' },
      { key: 'respawn_interval_hours', label: 'Respawn Intervall (h)', type: 'number' },
    ],
    forge_tournament: [
      { key: 'scoring_metric',   label: 'Metrik (crafts/power)', type: 'text'   },
      { key: 'min_item_tier',    label: 'Mindest-Tier',          type: 'number' },
      { key: 'bonus_multiplier', label: 'Bonus Multiplikator',   type: 'number' },
    ],
    dungeon_rush: [
      { key: 'dungeon_chapter',    label: 'Kapitel',          type: 'number' },
      { key: 'score_per_floor',    label: 'Punkte/Etage',     type: 'number' },
      { key: 'time_limit_minutes', label: 'Zeitlimit (min)',  type: 'number' },
    ],
    trade_expedition: [
      { key: 'trade_routes',      label: 'Handelsrouten',        type: 'number' },
      { key: 'profit_multiplier', label: 'Gewinn Multiplikator', type: 'number' },
    ],
  };

  events: AdminEvent[] = [];
  loading = false;
  error = '';

  selectedEvent: AdminEvent | null = null;
  items: ShopItem[] = [];
  itemsLoading = false;

  rankRewards: RankReward[] = [];
  rankRewardsLoading = false;
  showAddRankReward = false;
  addingRankReward = false;
  rankRewardForm = {
    rank_from: '1',
    rank_to: '1',
    reward_type: 'gold',
    amount: '',
    item_id: '',
    leaderboard_type: 'solo',
  };

  showCreate = false;
  creating = false;
  createForm = {
    name: '',
    description: '',
    starts_at: '',
    ends_at: '',
    currency_name: 'Event-Muenzen',
    banner_color: '#D4A84B',
    event_type: 'collection',
    notify_on_start: false,
  };
  typeConfigDraft: Record<string, string> = {};

  showAddItem = false;
  addingItem = false;
  itemForm = {
    name: '',
    description: '',
    icon: 'event',
    currency_cost: '',
    max_per_player: '1',
    sort_order: '0'
  };

  giveUsername = '';
  giveAmount = '';
  giving = false;
  giveResult = '';

  constructor(private readonly api: ApiService) {}

  ngOnInit(): void {
    this.loadEvents();
  }

  get activeCount(): number {
    return this.events.filter(e => e.status === 'active').length;
  }

  get upcomingCount(): number {
    return this.events.filter(e => e.status === 'upcoming').length;
  }

  get currentTypeConfigFields(): Array<{ key: string; label: string; type: 'text' | 'number' }> {
    return this.EVENT_TYPE_CONFIGS[this.createForm.event_type] ?? [];
  }

  onEventTypeChange(): void {
    this.typeConfigDraft = {};
  }

  eventTypeLabel(type: string): string {
    return this.EVENT_TYPES.find(t => t.value === type)?.label ?? type;
  }

  loadEvents(): void {
    this.loading = true;
    this.error = '';

    this.api.get<{ events: AdminEvent[] }>('/api/admin/events').subscribe({
      next: res => {
        this.events = res.events ?? [];
        this.loading = false;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Events konnten nicht geladen werden.';
        this.loading = false;
      }
    });
  }

  private buildTypeConfig(): Record<string, unknown> {
    const result: Record<string, unknown> = {};
    for (const f of this.currentTypeConfigFields) {
      const val = this.typeConfigDraft[f.key];
      if (!val) continue;
      result[f.key] = f.type === 'number' ? Number(val) : val;
    }
    return result;
  }

  createEvent(): void {
    if (!this.createForm.name.trim() || !this.createForm.starts_at || !this.createForm.ends_at) {
      this.error = 'Name, Startdatum und Enddatum sind Pflichtfelder.';
      return;
    }

    this.creating = true;
    this.error = '';

    this.api.post<{ event: AdminEvent }>('/api/admin/events', {
      ...this.createForm,
      starts_at: new Date(this.createForm.starts_at).toISOString(),
      ends_at: new Date(this.createForm.ends_at).toISOString(),
      type_config: this.buildTypeConfig(),
    }).subscribe({
      next: () => {
        this.creating = false;
        this.showCreate = false;
        this.createForm = {
          name: '',
          description: '',
          starts_at: '',
          ends_at: '',
          currency_name: 'Event-Muenzen',
          banner_color: '#D4A84B',
          event_type: 'collection',
          notify_on_start: false,
        };
        this.typeConfigDraft = {};
        this.loadEvents();
      },
      error: err => {
        this.error = err?.error?.error ?? 'Event konnte nicht erstellt werden.';
        this.creating = false;
      }
    });
  }

  openDetail(event: AdminEvent): void {
    this.selectedEvent = event;
    this.showAddItem = false;
    this.showAddRankReward = false;
    this.giveUsername = '';
    this.giveAmount = '';
    this.giveResult = '';
    this.items = [];
    this.rankRewards = [];
    this.loadItems(event.id);
    this.loadRankRewards(event.id);
  }

  backToList(): void {
    this.selectedEvent = null;
    this.items = [];
    this.rankRewards = [];
    this.loadEvents();
  }

  loadItems(eventId: string): void {
    this.itemsLoading = true;
    this.api.get<{ items: ShopItem[] }>(`/api/admin/events/${eventId}/items`).subscribe({
      next: res => {
        this.items = res.items ?? [];
        this.itemsLoading = false;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Items konnten nicht geladen werden.';
        this.itemsLoading = false;
      }
    });
  }

  loadRankRewards(eventId: string): void {
    this.rankRewardsLoading = true;
    this.api.get<{ rewards: RankReward[] }>(`/api/admin/events/${eventId}/rank_rewards`).subscribe({
      next: res => {
        this.rankRewards = res.rewards ?? [];
        this.rankRewardsLoading = false;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Rang-Belohnungen konnten nicht geladen werden.';
        this.rankRewardsLoading = false;
      }
    });
  }

  addRankReward(): void {
    if (!this.selectedEvent) return;

    const rankFrom = parseInt(this.rankRewardForm.rank_from, 10);
    const rankTo   = parseInt(this.rankRewardForm.rank_to, 10);
    if (!rankFrom || !rankTo || rankFrom < 1 || rankTo < rankFrom) {
      this.error = 'Rang-Bereich ungueltig (von >= 1, bis >= von).';
      return;
    }
    if (this.rankRewardForm.reward_type === 'gold' && !this.rankRewardForm.amount) {
      this.error = 'Betrag fuer Gold-Belohnung erforderlich.';
      return;
    }
    if (this.rankRewardForm.reward_type === 'item' && !this.rankRewardForm.item_id.trim()) {
      this.error = 'Item-ID fuer Item-Belohnung erforderlich.';
      return;
    }

    this.addingRankReward = true;
    this.error = '';

    const body: Record<string, unknown> = {
      rank_from: rankFrom,
      rank_to:   rankTo,
      reward_type: this.rankRewardForm.reward_type,
      leaderboard_type: this.rankRewardForm.leaderboard_type,
    };
    if (this.rankRewardForm.reward_type === 'gold') {
      body['amount'] = parseInt(this.rankRewardForm.amount, 10);
    } else {
      body['item_id'] = this.rankRewardForm.item_id.trim();
    }

    this.api.post<{ reward: RankReward }>(`/api/admin/events/${this.selectedEvent.id}/rank_rewards`, body).subscribe({
      next: () => {
        this.addingRankReward = false;
        this.showAddRankReward = false;
        this.rankRewardForm = { rank_from: '1', rank_to: '1', reward_type: 'gold', amount: '', item_id: '', leaderboard_type: 'solo' };
        this.loadRankRewards(this.selectedEvent!.id);
      },
      error: err => {
        this.error = err?.error?.error ?? 'Rang-Belohnung konnte nicht hinzugefuegt werden.';
        this.addingRankReward = false;
      }
    });
  }

  deleteRankReward(reward: RankReward): void {
    if (!this.selectedEvent) return;
    if (!confirm(`Rang-Belohnung Rang ${reward.rank_from}-${reward.rank_to} loeschen?`)) return;

    this.api.delete<{ success: boolean }>(`/api/admin/events/${this.selectedEvent.id}/rank_rewards/${reward.id}`).subscribe({
      next: () => {
        this.rankRewards = this.rankRewards.filter(r => r.id !== reward.id);
      },
      error: err => {
        this.error = err?.error?.error ?? 'Rang-Belohnung konnte nicht geloescht werden.';
      }
    });
  }

  endNow(event: AdminEvent): void {
    if (!confirm(`Event "${event.name}" jetzt beenden?`)) return;

    this.api.put<{ event: AdminEvent }>(`/api/admin/events/${event.id}`, { end_now: true }).subscribe({
      next: () => {
        if (this.selectedEvent?.id === event.id) {
          this.loadItems(event.id);
        }
        this.loadEvents();
      },
      error: err => {
        this.error = err?.error?.error ?? 'Konnte Event nicht beenden.';
      }
    });
  }

  deleteEvent(event: AdminEvent): void {
    if (!confirm(`Event "${event.name}" wirklich loeschen?`)) return;

    this.api.delete<{ success: boolean }>(`/api/admin/events/${event.id}`).subscribe({
      next: () => {
        if (this.selectedEvent?.id === event.id) {
          this.backToList();
        } else {
          this.loadEvents();
        }
      },
      error: err => {
        this.error = err?.error?.error ?? 'Event konnte nicht geloescht werden.';
      }
    });
  }

  addItem(): void {
    if (!this.selectedEvent) return;

    if (!this.itemForm.name.trim() || !this.itemForm.currency_cost) {
      this.error = 'Name und Kosten sind Pflichtfelder.';
      return;
    }

    this.addingItem = true;
    this.error = '';

    this.api.post<{ item: ShopItem }>(`/api/admin/events/${this.selectedEvent.id}/items`, {
      name: this.itemForm.name.trim(),
      description: this.itemForm.description,
      icon: this.itemForm.icon || 'event',
      currency_cost: parseInt(this.itemForm.currency_cost, 10),
      max_per_player: parseInt(this.itemForm.max_per_player, 10) || 1,
      sort_order: parseInt(this.itemForm.sort_order, 10) || 0
    }).subscribe({
      next: () => {
        this.addingItem = false;
        this.showAddItem = false;
        this.itemForm = { name: '', description: '', icon: 'event', currency_cost: '', max_per_player: '1', sort_order: '0' };
        this.loadItems(this.selectedEvent!.id);
      },
      error: err => {
        this.error = err?.error?.error ?? 'Item konnte nicht hinzugefuegt werden.';
        this.addingItem = false;
      }
    });
  }

  deleteItem(item: ShopItem): void {
    if (!this.selectedEvent) return;
    if (!confirm(`Item "${item.name}" loeschen?`)) return;

    this.api.delete<{ success: boolean }>(`/api/admin/events/${this.selectedEvent.id}/items/${item.id}`).subscribe({
      next: () => {
        this.items = this.items.filter(i => i.id !== item.id);
      },
      error: err => {
        this.error = err?.error?.error ?? 'Item konnte nicht geloescht werden.';
      }
    });
  }

  giveCurrency(): void {
    if (!this.selectedEvent) return;

    const amount = parseInt(this.giveAmount, 10);
    if (!this.giveUsername.trim() || !amount || amount <= 0) {
      this.giveResult = 'Spielername und Betrag (> 0) sind erforderlich.';
      return;
    }

    this.giving = true;
    this.giveResult = '';

    this.api.post<{ new_balance: number }>(`/api/admin/events/${this.selectedEvent.id}/give_currency`, {
      username: this.giveUsername.trim(),
      amount
    }).subscribe({
      next: res => {
        this.giveResult = `OK: ${this.giveUsername} hat jetzt ${res.new_balance} ${this.selectedEvent!.currency_name}.`;
        this.giveUsername = '';
        this.giveAmount = '';
        this.giving = false;
      },
      error: err => {
        this.giveResult = err?.error?.error ?? 'Fehler beim Vergeben.';
        this.giving = false;
      }
    });
  }

  fmtDate(iso: string): string {
    try {
      return new Date(iso).toLocaleString('de-DE');
    } catch {
      return iso;
    }
  }
}
