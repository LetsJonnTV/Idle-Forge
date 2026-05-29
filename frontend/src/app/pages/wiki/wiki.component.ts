import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/api.service';

export interface ItemBlueprint {
  id: string;
  slot: string;
  name: string;
  base_power: number;
  icon_path: string;
}

@Component({
  selector: 'app-wiki',
  templateUrl: './wiki.component.html',
  styleUrls: ['./wiki.component.scss']
})
export class WikiComponent implements OnInit {
  items: ItemBlueprint[] = [];
  filtered: ItemBlueprint[] = [];
  loading = true;
  error = '';

  searchQuery = '';
  selectedSlot = '';

  readonly slots = ['weapon', 'armor', 'helm', 'gloves', 'boots', 'ring'];
  readonly slotLabels: Record<string, string> = {
    weapon: '⚔️ Waffe',
    armor: '🛡️ Rüstung',
    helm: '⛑️ Helm',
    gloves: '🧤 Handschuhe',
    boots: '👢 Stiefel',
    ring: '💍 Ring',
  };

  constructor(private api: ApiService) {}

  ngOnInit(): void {
    this.loadItems();
  }

  loadItems(): void {
    this.loading = true;
    this.error = '';
    this.api.get<{ items: ItemBlueprint[] }>('/api/items').subscribe({
      next: (res) => {
        this.items = res.items ?? [];
        this.applyFilter();
        this.loading = false;
      },
      error: () => {
        this.error = 'Fehler beim Laden der Items.';
        this.loading = false;
      }
    });
  }

  applyFilter(): void {
    let result = [...this.items];
    if (this.selectedSlot) {
      result = result.filter(i => i.slot === this.selectedSlot);
    }
    if (this.searchQuery.trim()) {
      const q = this.searchQuery.trim().toLowerCase();
      result = result.filter(i => i.name.toLowerCase().includes(q) || i.id.toLowerCase().includes(q));
    }
    this.filtered = result;
  }

  onSearch(): void { this.applyFilter(); }
  onSlotChange(): void { this.applyFilter(); }
  clearFilters(): void {
    this.searchQuery = '';
    this.selectedSlot = '';
    this.applyFilter();
  }

  slotLabel(slot: string): string {
    return this.slotLabels[slot] ?? slot;
  }

  powerClass(power: number): string {
    if (power >= 30) return 'power-legendary';
    if (power >= 22) return 'power-epic';
    if (power >= 15) return 'power-rare';
    if (power >= 8)  return 'power-uncommon';
    return 'power-common';
  }
}
