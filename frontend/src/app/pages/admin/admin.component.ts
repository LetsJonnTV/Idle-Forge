import { Component, OnInit, OnDestroy } from '@angular/core';
import { Subject, Subscription } from 'rxjs';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { AdminService, AdminPlayer } from '../../core/admin.service';

interface ResetPwState {
  visible: boolean;
  pw:      string;
  loading: boolean;
  msg:     string;
}

interface GiveState {
  visible: boolean;
  type:    'gold' | 'item';
  amount:  number;
  itemId:  string;
  loading: boolean;
  msg:     string;
}

@Component({
  selector: 'app-admin',
  templateUrl: './admin.component.html',
  styleUrls: ['./admin.component.scss']
})
export class AdminComponent implements OnInit, OnDestroy {
  players:     AdminPlayer[] = [];
  loading      = false;
  error        = '';
  searchQuery  = '';

  /* Per-row inline form state */
  resetPwMap: Record<string, ResetPwState> = {};
  giveMap:    Record<string, GiveState>    = {};
  rowMessages: Record<string, string>      = {};

  private searchSubject = new Subject<string>();
  private searchSub!: Subscription;

  constructor(private adminService: AdminService) {}

  ngOnInit(): void {
    this.loadPlayers();

    this.searchSub = this.searchSubject
      .pipe(debounceTime(300), distinctUntilChanged())
      .subscribe(q => this.loadPlayers(q || undefined));
  }

  ngOnDestroy(): void {
    this.searchSub?.unsubscribe();
  }

  onSearchChange(val: string): void {
    this.searchSubject.next(val);
  }

  loadPlayers(search?: string): void {
    this.loading = true;
    this.error   = '';
    this.adminService.getPlayers(search).subscribe({
      next:  res => { this.players = res.players ?? []; this.loading = false; },
      error: err => {
        this.error   = err?.error?.message ?? 'Fehler beim Laden der Spieler.';
        this.loading = false;
      }
    });
  }

  /* ── Reset Password ────────────────────────────────── */
  toggleResetPw(id: string): void {
    if (!this.resetPwMap[id]) {
      this.resetPwMap[id] = { visible: false, pw: '', loading: false, msg: '' };
    }
    this.resetPwMap[id].visible = !this.resetPwMap[id].visible;
    // Close give form if open
    if (this.giveMap[id]) this.giveMap[id].visible = false;
  }

  doResetPw(player: AdminPlayer): void {
    const state = this.resetPwMap[player.id];
    if (!state?.pw?.trim()) {
      state.msg = '✗ Passwort darf nicht leer sein.';
      return;
    }
    state.loading = true;
    state.msg     = '';
    this.adminService.resetPassword(player.id, state.pw.trim()).subscribe({
      next: () => {
        state.msg     = '✓ Passwort erfolgreich zurückgesetzt!';
        state.loading = false;
        state.pw      = '';
      },
      error: err => {
        state.msg     = '✗ ' + (err?.error?.message ?? 'Fehler');
        state.loading = false;
      }
    });
  }

  /* ── Block / Unblock ───────────────────────────────── */
  toggleBlock(player: AdminPlayer): void {
    const newBlocked = !player.is_blocked;
    this.adminService.setBlocked(player.id, newBlocked).subscribe({
      next: () => {
        player.is_blocked            = newBlocked;
        this.rowMessages[player.id]  = newBlocked ? '🚫 Gesperrt' : '✓ Entsperrt';
        setTimeout(() => delete this.rowMessages[player.id], 2500);
      },
      error: err => {
        this.rowMessages[player.id] = '✗ ' + (err?.error?.message ?? 'Fehler');
        setTimeout(() => delete this.rowMessages[player.id], 3000);
      }
    });
  }

  /* ── Give Reward ───────────────────────────────────── */
  toggleGive(id: string): void {
    if (!this.giveMap[id]) {
      this.giveMap[id] = { visible: false, type: 'gold', amount: 100, itemId: '', loading: false, msg: '' };
    }
    this.giveMap[id].visible = !this.giveMap[id].visible;
    // Close reset-pw form if open
    if (this.resetPwMap[id]) this.resetPwMap[id].visible = false;
  }

  doGive(player: AdminPlayer): void {
    const state = this.giveMap[player.id];
    if (!state) return;

    if (state.type === 'gold' && (!state.amount || state.amount <= 0)) {
      state.msg = '✗ Bitte eine gültige Goldmenge eingeben.';
      return;
    }
    if (state.type === 'item' && !state.itemId?.trim()) {
      state.msg = '✗ Bitte eine Item-ID eingeben.';
      return;
    }

    state.loading = true;
    state.msg     = '';

    const amount = state.type === 'gold' ? state.amount    : undefined;
    const itemId = state.type === 'item' ? state.itemId.trim() : undefined;

    this.adminService.giveReward(player.id, state.type, amount, itemId).subscribe({
      next: () => {
        state.msg     = '✓ Belohnung vergeben!';
        state.loading = false;
      },
      error: err => {
        state.msg     = '✗ ' + (err?.error?.message ?? 'Fehler');
        state.loading = false;
      }
    });
  }

  /* ── Delete Player ─────────────────────────────────── */
  deletePlayer(player: AdminPlayer): void {
    if (!confirm(
      `Spieler "${player.username}" wirklich unwiderruflich löschen?\n\nDiese Aktion kann nicht rückgängig gemacht werden.`
    )) return;

    this.adminService.deletePlayer(player.id).subscribe({
      next: () => {
        this.players = this.players.filter(p => p.id !== player.id);
      },
      error: err => {
        this.error = err?.error?.message ?? 'Fehler beim Löschen des Spielers.';
      }
    });
  }

  /* ── Helpers ───────────────────────────────────────── */
  formatDate(iso: string): string {
    if (!iso) return '—';
    try {
      return new Date(iso).toLocaleDateString('de-DE', {
        year: 'numeric', month: '2-digit', day: '2-digit'
      });
    } catch { return iso; }
  }

  getResetState(id: string): ResetPwState {
    return this.resetPwMap[id] ?? { visible: false, pw: '', loading: false, msg: '' };
  }

  getGiveState(id: string): GiveState {
    return this.giveMap[id] ?? { visible: false, type: 'gold', amount: 100, itemId: '', loading: false, msg: '' };
  }
}
