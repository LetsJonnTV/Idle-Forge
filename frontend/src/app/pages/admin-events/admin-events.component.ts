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

interface TypeConfigField {
  key: string;
  label: string;
  type: 'text' | 'number' | 'boolean';
  placeholder?: string;
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

  readonly EVENT_TYPE_CONFIGS: Record<string, TypeConfigField[]> = {
    collection: [
      { key: 'mission_durations_minutes', label: 'Missionsdauern (CSV, z.B. 30,120,480)', type: 'text', placeholder: '30,120,480' },
      { key: 'resource_yield_per_mission', label: 'Ressourcen pro Mission', type: 'number' },
      { key: 'enable_solo_leaderboard', label: 'Solo-Rangliste aktiv', type: 'boolean' },
      { key: 'enable_clan_leaderboard', label: 'Clan-Rangliste aktiv', type: 'boolean' },
      { key: 'max_parallel_missions', label: 'Max. parallele Missionen', type: 'number' },
    ],
    world_boss: [
      { key: 'boss_name', label: 'Boss-Name', type: 'text' },
      { key: 'boss_hp', label: 'Boss-HP', type: 'number' },
      { key: 'boss_duration_minutes', label: 'Boss-Dauer (Minuten)', type: 'number' },
      { key: 'max_damage_per_attack', label: 'Max. Schaden pro Angriff', type: 'number' },
      { key: 'boss_icon', label: 'Boss-Icon Vorlage', type: 'text', placeholder: 'inferno_lord' },
      { key: 'enable_phase_two', label: '2. Boss-Phase aktiv', type: 'boolean' },
      { key: 'phase_two_trigger_hp_pct', label: 'Phase-2 Trigger (%)', type: 'number' },
    ],
    forge_tournament: [
      { key: 'min_item_tier', label: 'Mindest-Tier (z.B. rare)', type: 'text' },
      { key: 'tier_multipliers_json', label: 'Tier-Multiplikatoren (JSON)', type: 'text', placeholder: '{"common":1,"uncommon":2,"rare":5}' },
      { key: 'count_bulk_crafting', label: 'Bulk-Crafting zaehlt', type: 'boolean' },
    ],
    dungeon_rush: [
      { key: 'dungeon_name', label: 'Dungeon-Name', type: 'text' },
      { key: 'dungeon_description', label: 'Dungeon-Beschreibung', type: 'text' },
      { key: 'difficulty', label: 'Schwierigkeit', type: 'text', placeholder: 'normal|hard|nightmare' },
      { key: 'max_clears_per_day', label: 'Max. Clears pro Tag', type: 'number' },
      { key: 'min_power_required', label: 'Mindest-Staerke', type: 'number' },
    ],
    trade_expedition: [
      { key: 'routes_json', label: 'Routen (JSON)', type: 'text', placeholder: '[{"name":"Kurz","minutes":30,"yield":80}]' },
      { key: 'clan_bonus_multiplier', label: 'Clan-Bonus Multiplikator', type: 'number' },
      { key: 'max_active_expeditions', label: 'Max. aktive Expeditionen', type: 'number' },
      { key: 'currency_yield_multiplier', label: 'Waehrungs-Multiplikator', type: 'number' },
      { key: 'enable_rank_rewards', label: 'Rang-Belohnungen aktiv', type: 'boolean' },
    ],
  };

  readonly EVENT_TYPE_PREVIEWS: Record<string, { title: string; description: string; objective: string }> = {
    collection: {
      title: 'Sammel-Event',
      description: 'Spieler schicken Missionen und sammeln Event-Ressourcen solo oder im Clan.',
      objective: 'Mehr Ressourcen sammeln als andere.'
    },
    world_boss: {
      title: 'Community-Boss',
      description: 'Ein globaler Boss mit gemeinsamem HP-Pool. Schaden zaehlt fuer Ranglisten.',
      objective: 'Maximalen Boss-Schaden beitragen.'
    },
    forge_tournament: {
      title: 'Schmiede-Turnier',
      description: 'Geschmiedete Items geben Punkte, hoehere Tiers geben Bonus.',
      objective: 'Ueber Laufzeit die meisten Schmiede-Punkte sammeln.'
    },
    dungeon_rush: {
      title: 'Dungeon-Rush',
      description: 'Exklusiver Event-Dungeon ist nur waehrend des Events verfuegbar.',
      objective: 'Moeglichst viele Clears im Zeitfenster schaffen.'
    },
    trade_expedition: {
      title: 'Handels-Expedition',
      description: 'Routen mit unterschiedlicher Dauer/Ausbeute, optional mit Clan-Bonus.',
      objective: 'Hoechste Event-Waehrungsausbeute erreichen.'
    },
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

  savingDetail = false;
  editForm = {
    name: '',
    description: '',
    starts_at: '',
    ends_at: '',
    currency_name: 'Event-Muenzen',
    banner_color: '#D4A84B',
    event_type: 'collection',
    notify_on_start: false,
  };
  selectedTypeConfigDraft: Record<string, string> = {};

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

  get currentTypeConfigFields(): TypeConfigField[] {
    return this.EVENT_TYPE_CONFIGS[this.createForm.event_type] ?? [];
  }

  get currentEditTypeConfigFields(): TypeConfigField[] {
    return this.EVENT_TYPE_CONFIGS[this.editForm.event_type] ?? [];
  }

  get currentCreateTypePreview(): { title: string; description: string; objective: string } {
    return this.EVENT_TYPE_PREVIEWS[this.createForm.event_type] ?? this.EVENT_TYPE_PREVIEWS['collection'];
  }

  get currentEditTypePreview(): { title: string; description: string; objective: string } {
    return this.EVENT_TYPE_PREVIEWS[this.editForm.event_type] ?? this.EVENT_TYPE_PREVIEWS['collection'];
  }

  onEventTypeChange(): void {
    this.typeConfigDraft = {};
  }

  onEditEventTypeChange(): void {
    this.selectedTypeConfigDraft = {};
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

  private parseTypeConfigValue(field: TypeConfigField, raw: string): unknown {
    if (field.type === 'number') {
      const numeric = Number(raw);
      return Number.isNaN(numeric) ? null : numeric;
    }

    if (field.type === 'boolean') {
      return raw === 'true';
    }

    if (field.key.endsWith('_json')) {
      try {
        return JSON.parse(raw);
      } catch {
        return raw;
      }
    }

    if (field.key.endsWith('_minutes') && raw.includes(',')) {
      return raw
        .split(',')
        .map((v) => Number(v.trim()))
        .filter((v) => !Number.isNaN(v));
    }

    return raw;
  }

  private buildTypeConfig(fields: TypeConfigField[], source: Record<string, string>): Record<string, unknown> {
    const result: Record<string, unknown> = {};
    for (const field of fields) {
      const raw = source[field.key];
      if (raw === undefined || raw === null || raw === '') continue;
      const parsed = this.parseTypeConfigValue(field, raw);
      if (parsed !== null) {
        result[field.key] = parsed;
      }
    }
    return result;
  }

  private toDatetimeLocal(iso: string): string {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '';
    const pad = (n: number) => n.toString().padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private draftFromTypeConfig(fields: TypeConfigField[], config: Record<string, unknown>): Record<string, string> {
    const draft: Record<string, string> = {};
    for (const field of fields) {
      const value = config[field.key];
      if (value === undefined || value === null) continue;

      if (Array.isArray(value)) {
        draft[field.key] = value.join(',');
        continue;
      }

      if (typeof value === 'object') {
        draft[field.key] = JSON.stringify(value);
        continue;
      }

      if (typeof value === 'boolean') {
        draft[field.key] = value ? 'true' : 'false';
        continue;
      }

      if (typeof value === 'string' || typeof value === 'number') {
        draft[field.key] = String(value);
      }
    }
    return draft;
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
      type_config: this.buildTypeConfig(this.currentTypeConfigFields, this.typeConfigDraft),
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
    this.editForm = {
      name: event.name,
      description: event.description,
      starts_at: this.toDatetimeLocal(event.starts_at),
      ends_at: this.toDatetimeLocal(event.ends_at),
      currency_name: event.currency_name,
      banner_color: event.banner_color,
      event_type: event.event_type,
      notify_on_start: !!event.notify_on_start,
    };
    const cfg = event.type_config ?? {};
    const fields = this.EVENT_TYPE_CONFIGS[event.event_type] ?? [];
    this.selectedTypeConfigDraft = this.draftFromTypeConfig(fields, cfg);

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

  saveEventDetails(): void {
    if (!this.selectedEvent) return;
    if (!this.editForm.name.trim() || !this.editForm.starts_at || !this.editForm.ends_at) {
      this.error = 'Name, Startdatum und Enddatum sind Pflichtfelder.';
      return;
    }

    this.savingDetail = true;
    this.error = '';

    const payload = {
      name: this.editForm.name.trim(),
      description: this.editForm.description,
      starts_at: new Date(this.editForm.starts_at).toISOString(),
      ends_at: new Date(this.editForm.ends_at).toISOString(),
      currency_name: this.editForm.currency_name,
      banner_color: this.editForm.banner_color,
      event_type: this.editForm.event_type,
      notify_on_start: this.editForm.notify_on_start,
      type_config: this.buildTypeConfig(this.currentEditTypeConfigFields, this.selectedTypeConfigDraft),
    };

    this.api.put<{ event: AdminEvent }>(`/api/admin/events/${this.selectedEvent.id}`, payload).subscribe({
      next: res => {
        this.savingDetail = false;
        this.selectedEvent = res.event;
        this.editForm = {
          name: res.event.name,
          description: res.event.description,
          starts_at: this.toDatetimeLocal(res.event.starts_at),
          ends_at: this.toDatetimeLocal(res.event.ends_at),
          currency_name: res.event.currency_name,
          banner_color: res.event.banner_color,
          event_type: res.event.event_type,
          notify_on_start: !!res.event.notify_on_start,
        };
        const fields = this.EVENT_TYPE_CONFIGS[res.event.event_type] ?? [];
        this.selectedTypeConfigDraft = this.draftFromTypeConfig(fields, res.event.type_config ?? {});
        this.loadEvents();
      },
      error: err => {
        this.error = err?.error?.error ?? 'Event konnte nicht aktualisiert werden.';
        this.savingDetail = false;
      }
    });
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

    const rankFrom = Number.parseInt(this.rankRewardForm.rank_from, 10);
    const rankTo   = Number.parseInt(this.rankRewardForm.rank_to, 10);
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
      body['amount'] = Number.parseInt(this.rankRewardForm.amount, 10);
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
      currency_cost: Number.parseInt(this.itemForm.currency_cost, 10),
      max_per_player: Number.parseInt(this.itemForm.max_per_player, 10) || 1,
      sort_order: Number.parseInt(this.itemForm.sort_order, 10) || 0
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

    const amount = Number.parseInt(this.giveAmount, 10);
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

  toBooleanDraft(value: string | undefined): boolean {
    return value === 'true';
  }

  setBooleanDraft(target: Record<string, string>, key: string, checked: boolean): void {
    target[key] = checked ? 'true' : 'false';
  }

  fmtDate(iso: string): string {
    try {
      return new Date(iso).toLocaleString('de-DE');
    } catch {
      return iso;
    }
  }
}
