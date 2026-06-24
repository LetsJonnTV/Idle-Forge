import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/api.service';

interface AdminClan {
  id: string;
  name: string;
  level: number;
  xp: number;
  description: string;
  created_at: string;
  member_count: number;
  leader: { id: string; username: string } | null;
}

interface ClanMember {
  player_id: string;
  joined_at: string;
  player: { id: string; username: string; total_strength: number; prestige_level: number; chapter: number };
}

@Component({
  selector: 'app-admin-clans',
  templateUrl: './admin-clans.component.html',
  styleUrls: ['./admin-clans.component.scss']
})
export class AdminClansComponent implements OnInit {
  clans: AdminClan[] = [];
  loading = false;
  error = '';
  searchQuery = '';

  selectedClan: AdminClan | null = null;
  members: ClanMember[] = [];
  membersLoading = false;

  constructor(private readonly api: ApiService) {}

  ngOnInit(): void {
    this.loadClans();
  }

  loadClans(): void {
    this.loading = true;
    this.error = '';
    const query = this.searchQuery.trim() ? `?q=${encodeURIComponent(this.searchQuery.trim())}` : '';
    this.api.get<{ clans: AdminClan[] }>(`/api/admin/clans${query}`).subscribe({
      next: res => { this.clans = res.clans ?? []; this.loading = false; },
      error: err => {
        this.error = err?.error?.error ?? 'Clans konnten nicht geladen werden.';
        this.loading = false;
      }
    });
  }

  openClan(clan: AdminClan): void {
    this.selectedClan = clan;
    this.members = [];
    this.membersLoading = true;
    this.api.get<{ clan: AdminClan; members: ClanMember[] }>(`/api/admin/clans/${clan.id}`).subscribe({
      next: res => { this.members = res.members ?? []; this.membersLoading = false; },
      error: err => {
        this.error = err?.error?.error ?? 'Mitglieder konnten nicht geladen werden.';
        this.membersLoading = false;
      }
    });
  }

  backToList(): void {
    this.selectedClan = null;
    this.members = [];
    this.loadClans();
  }

  deleteClan(clan: AdminClan): void {
    if (!confirm(`Clan "${clan.name}" wirklich unwiderruflich löschen?\n\nAlle Mitglieder werden aus dem Clan entfernt.`)) return;

    this.api.delete<{ success: boolean }>(`/api/admin/clans/${clan.id}`).subscribe({
      next: () => {
        if (this.selectedClan?.id === clan.id) {
          this.backToList();
        } else {
          this.clans = this.clans.filter(c => c.id !== clan.id);
        }
      },
      error: err => {
        this.error = err?.error?.error ?? 'Clan konnte nicht gelöscht werden.';
      }
    });
  }

  kickMember(member: ClanMember): void {
    if (!this.selectedClan) return;
    if (!confirm(`Spieler "${member.player.username}" aus dem Clan kicken?`)) return;

    this.api.patch<{ success: boolean }>(`/api/admin/clans/${this.selectedClan.id}`, {
      kick_player_id: member.player_id
    }).subscribe({
      next: () => {
        this.members = this.members.filter(m => m.player_id !== member.player_id);
        if (this.selectedClan) this.selectedClan.member_count = this.members.length;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Mitglied konnte nicht gekickt werden.';
      }
    });
  }

  isLeader(member: ClanMember): boolean {
    return member.player_id === this.selectedClan?.leader?.id;
  }

  fmtDate(iso: string): string {
    try { return new Date(iso).toLocaleDateString('de-DE'); } catch { return iso; }
  }
}
