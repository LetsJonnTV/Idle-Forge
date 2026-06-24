import { Component, OnInit } from '@angular/core';

import { ApiService } from '../../core/api.service';

interface Clan {
  id: string;
  name: string;
}

interface War {
  id: string;
  status: string;
  clan_a_name: string;
  clan_b_name: string;
  clan_a_points: number;
  clan_b_points: number;
  winner_name: string | null;
  participant_count: number;
  started_at: string;
  ends_at: string;
}

@Component({
  selector: 'app-admin-clan-wars',
  templateUrl: './admin-clan-wars.component.html',
  styleUrls: ['./admin-clan-wars.component.scss']
})
export class AdminClanWarsComponent implements OnInit {
  wars: War[] = [];
  clans: Clan[] = [];

  loading = false;
  error = '';
  success = '';

  clanAId = '';
  clanBId = '';
  durationDays = '7';
  creating = false;

  constructor(private readonly api: ApiService) {}

  ngOnInit(): void {
    this.loadWars();
    this.loadClans();
  }

  get activeWars(): War[] {
    return this.wars.filter(w => w.status === 'active');
  }

  get pastWars(): War[] {
    return this.wars.filter(w => w.status !== 'active');
  }

  loadWars(): void {
    this.loading = true;
    this.error = '';

    this.api.get<{ wars: War[] }>('/api/admin/clan_wars').subscribe({
      next: res => {
        this.wars = res.wars ?? [];
        this.loading = false;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Gildenkaempfe konnten nicht geladen werden.';
        this.loading = false;
      }
    });
  }

  loadClans(): void {
    this.api.get<{ clans: Clan[] }>('/api/clans').subscribe({
      next: res => {
        this.clans = (res.clans ?? []).map(c => ({ id: c.id, name: c.name }));
      },
      error: () => {
        // Intentionally empty: page still works without the clan dropdown data.
      }
    });
  }

  createWar(): void {
    if (!this.clanAId || !this.clanBId) {
      this.error = 'Bitte beide Clans waehlen.';
      return;
    }
    if (this.clanAId === this.clanBId) {
      this.error = 'Die Clans muessen unterschiedlich sein.';
      return;
    }

    this.creating = true;
    this.error = '';
    this.success = '';

    this.api.post<{ war: War }>('/api/admin/clan_wars', {
      clan_a_id: this.clanAId,
      clan_b_id: this.clanBId,
      duration_days: parseInt(this.durationDays, 10)
    }).subscribe({
      next: () => {
        this.creating = false;
        this.success = 'Gildenkampf gestartet.';
        this.clanAId = '';
        this.clanBId = '';
        this.loadWars();
      },
      error: err => {
        this.error = err?.error?.error ?? 'Konnte Krieg nicht starten.';
        this.creating = false;
      }
    });
  }

  cancelWar(id: string): void {
    if (!confirm('Gildenkampf wirklich abbrechen?')) return;

    this.api.delete<{ success: boolean }>(`/api/admin/clan_wars?id=${id}`).subscribe({
      next: () => {
        this.success = 'Gildenkampf abgebrochen.';
        this.loadWars();
      },
      error: err => {
        this.error = err?.error?.error ?? 'Abbrechen fehlgeschlagen.';
      }
    });
  }

  fmtDate(iso: string): string {
    try {
      return new Date(iso).toLocaleDateString('de-DE');
    } catch {
      return iso;
    }
  }
}
