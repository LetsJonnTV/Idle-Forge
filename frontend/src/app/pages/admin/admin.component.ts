import { Component, OnInit, OnDestroy } from '@angular/core';
import { Subject, Subscription } from 'rxjs';
import { debounceTime, distinctUntilChanged } from 'rxjs/operators';
import { AdminService, AdminPlayer, ItemBlueprint } from '../../core/admin.service';

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
  activeTab: 'players' | 'items' = 'players';

  /* ── Players tab ─────────────────────────────────── */
  players:     AdminPlayer[] = [];
  loading      = false;
  error        = '';
  searchQuery  = '';

  resetPwMap: Record<string, ResetPwState> = {};
  giveMap:    Record<string, GiveState>    = {};
  rowMessages: Record<string, string>      = {};

  private searchSubject = new Subject<string>();
  private searchSub!: Subscription;

  /* ── Items tab ───────────────────────────────────── */
  items:         ItemBlueprint[] = [];
  itemsLoading   = false;
  itemsError     = '';
  itemSearch     = '';
  itemSlotFilter = '';
  itemMsg        = '';

  newItem = { id: '', slot: 'weapon', name: '', base_power: 1, icon_path: '' };
  newItemLoading = false;
  newItemMsg = '';

  editingItem: ItemBlueprint | null = null;
  editItemLoading = false;
  editItemMsg = '';

  readonly slots = ['weapon', 'armor', 'helm', 'gloves', 'boots', 'ring'];
  readonly slotLabels: Record<string, string> = {
    weapon: '⚔️ Waffe', armor: '🛡️ Rüstung', helm: '⛑️ Helm',
    gloves: '🧤 Handschuhe', boots: '👢 Stiefel', ring: '💍 Ring',
  };

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

  setTab(tab: 'players' | 'items'): void {
    this.activeTab = tab;
    if (tab === 'items' && this.items.length === 0) this.loadItems();
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

  /* ── Items tab ───────────────────────────────────── */
  loadItems(): void {
    this.itemsLoading = true;
    this.itemsError = '';
    this.adminService.getItems(this.itemSearch || undefined, this.itemSlotFilter || undefined).subscribe({
      next: res => { this.items = res.items ?? []; this.itemsLoading = false; },
      error: err => {
        this.itemsError = err?.error?.message ?? 'Fehler beim Laden der Items.';
        this.itemsLoading = false;
      }
    });
  }

  createItem(): void {
    if (!this.newItem.id || !this.newItem.name) {
      this.newItemMsg = '✗ ID und Name sind erforderlich.';
      return;
    }
    this.newItemLoading = true;
    this.newItemMsg = '';
    const payload = { ...this.newItem, icon_path: this.newItem.icon_path || undefined };
    this.adminService.createItem(payload).subscribe({
      next: res => {
        this.items = [res.item, ...this.items];
        this.newItem = { id: '', slot: 'weapon', name: '', base_power: 1, icon_path: '' };
        this.newItemMsg = '✓ Item erstellt!';
        this.newItemLoading = false;
        setTimeout(() => this.newItemMsg = '', 3000);
      },
      error: err => {
        this.newItemMsg = '✗ ' + (err?.error?.error ?? err?.error?.message ?? 'Fehler');
        this.newItemLoading = false;
      }
    });
  }

  startEditItem(item: ItemBlueprint): void {
    this.editingItem = { ...item };
    this.editItemMsg = '';
  }

  cancelEditItem(): void {
    this.editingItem = null;
    this.editItemMsg = '';
  }

  saveEditItem(): void {
    if (!this.editingItem) return;
    this.editItemLoading = true;
    this.editItemMsg = '';
    const { id, ...updates } = this.editingItem;
    this.adminService.updateItem(id, updates).subscribe({
      next: res => {
        const idx = this.items.findIndex(i => i.id === id);
        if (idx >= 0) this.items[idx] = res.item;
        this.editingItem = null;
        this.editItemLoading = false;
        this.itemMsg = '✓ Item aktualisiert!';
        setTimeout(() => this.itemMsg = '', 3000);
      },
      error: err => {
        this.editItemMsg = '✗ ' + (err?.error?.message ?? 'Fehler');
        this.editItemLoading = false;
      }
    });
  }

  deactivateItem(item: ItemBlueprint): void {
    if (!confirm(`Item "${item.name}" deaktivieren?`)) return;
    this.adminService.deactivateItem(item.id).subscribe({
      next: () => {
        item.is_active = false;
        this.itemMsg = `✓ "${item.name}" deaktiviert.`;
        setTimeout(() => this.itemMsg = '', 3000);
      },
      error: err => {
        this.itemMsg = '✗ ' + (err?.error?.message ?? 'Fehler');
        setTimeout(() => this.itemMsg = '', 3000);
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

  slotLabel(slot: string): string {
    return this.slotLabels[slot] ?? slot;
  }
}


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
