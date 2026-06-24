import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ApiService } from '../../core/api.service';
import { AuthService } from '../../core/auth.service';

interface Item {
  id: string;
  name: string;
  slot: string;
  tier: string;
  setId: string;
  power: number;
  sellValue: number;
  isLocked: boolean;
  isEquipped: boolean;
  enchantments: unknown[];
}

@Component({
  selector: 'app-inventory',
  templateUrl: './inventory.component.html',
  styleUrls: ['./inventory.component.scss']
})
export class InventoryComponent implements OnInit {
  readonly slotLabels: Record<string, string> = {
    weapon: 'Waffe',
    armor: 'Ruestung',
    helm: 'Helm',
    gloves: 'Handschuhe',
    boots: 'Stiefel',
    ring: 'Ring'
  };

  readonly tierOrder = ['common', 'uncommon', 'rare', 'epic', 'legendary'];

  items: Item[] = [];
  loading = false;
  error = '';

  activeSlot = 'all';
  actionLoadingId: string | null = null;
  confirmSellItem: Item | null = null;

  constructor(
    private readonly api: ApiService,
    private readonly auth: AuthService,
    private readonly router: Router
  ) {}

  ngOnInit(): void {
    this.loadInventory();
  }

  get visibleItems(): Item[] {
    if (this.activeSlot === 'all') return this.items;
    return this.items.filter(i => i.slot === this.activeSlot);
  }

  get slots(): string[] {
    return ['all', ...Array.from(new Set(this.items.map(i => i.slot)))];
  }

  get equippedCount(): number {
    return this.items.filter(i => i.isEquipped).length;
  }

  get rareOrBetterCount(): number {
    return this.items.filter(i => i.tier === 'epic' || i.tier === 'legendary').length;
  }

  loadInventory(): void {
    this.loading = true;
    this.error = '';

    this.api.get<{ items: Item[] }>('/api/players/me/inventory').subscribe({
      next: res => {
        this.items = (res.items ?? []).sort(
          (a, b) => b.power - a.power || this.tierOrder.indexOf(b.tier) - this.tierOrder.indexOf(a.tier)
        );
        this.loading = false;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Inventar konnte nicht geladen werden.';
        this.loading = false;
      }
    });
  }

  setSlot(slot: string): void {
    this.activeSlot = slot;
  }

  toggleEquip(item: Item): void {
    this.actionLoadingId = item.id;
    this.api.put<{ success: boolean }>(`/api/players/me/inventory/${item.id}`, { equip: !item.isEquipped }).subscribe({
      next: () => {
        this.items = this.items.map(i => {
          if (i.slot === item.slot && i.id !== item.id && !item.isEquipped && i.isEquipped) {
            return { ...i, isEquipped: false };
          }
          if (i.id === item.id) {
            return { ...i, isEquipped: !item.isEquipped };
          }
          return i;
        });
        this.actionLoadingId = null;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Aenderung fehlgeschlagen.';
        this.actionLoadingId = null;
      }
    });
  }

  openSellConfirm(item: Item): void {
    this.confirmSellItem = item;
  }

  cancelSellConfirm(): void {
    this.confirmSellItem = null;
  }

  sellItem(item: Item): void {
    this.actionLoadingId = item.id;
    this.confirmSellItem = null;
    this.api.delete<{ success: boolean }>(`/api/players/me/inventory/${item.id}`).subscribe({
      next: () => {
        this.items = this.items.filter(i => i.id !== item.id);
        this.actionLoadingId = null;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Verkauf fehlgeschlagen.';
        this.actionLoadingId = null;
      }
    });
  }

  logout(): void {
    this.auth.logout();
    this.router.navigate(['/']);
  }

  slotLabel(slot: string): string {
    return this.slotLabels[slot] ?? slot;
  }

  tierClass(tier: string): string {
    return `tier-${tier}`;
  }
}
