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

@Component({
  selector: 'app-admin-events',
  templateUrl: './admin-events.component.html',
  styleUrls: ['./admin-events.component.scss']
})
export class AdminEventsComponent implements OnInit {
  events: AdminEvent[] = [];
  loading = false;
  error = '';

  selectedEvent: AdminEvent | null = null;
  items: ShopItem[] = [];
  itemsLoading = false;

  showCreate = false;
  creating = false;
  createForm = {
    name: '',
    description: '',
    starts_at: '',
    ends_at: '',
    currency_name: 'Event-Muenzen',
    banner_color: '#D4A84B'
  };

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
      ends_at: new Date(this.createForm.ends_at).toISOString()
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
          banner_color: '#D4A84B'
        };
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
    this.giveUsername = '';
    this.giveAmount = '';
    this.giveResult = '';
    this.items = [];
    this.loadItems(event.id);
  }

  backToList(): void {
    this.selectedEvent = null;
    this.items = [];
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

  endNow(event: AdminEvent): void {
    if (!confirm(`Event \"${event.name}\" jetzt beenden?`)) return;

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
    if (!confirm(`Event \"${event.name}\" wirklich loeschen?`)) return;

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
        this.itemForm = {
          name: '',
          description: '',
          icon: 'event',
          currency_cost: '',
          max_per_player: '1',
          sort_order: '0'
        };
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
    if (!confirm(`Item \"${item.name}\" loeschen?`)) return;

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
