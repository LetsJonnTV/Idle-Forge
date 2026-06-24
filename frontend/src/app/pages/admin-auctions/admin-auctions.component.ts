import { Component, OnInit } from '@angular/core';

import { ApiService } from '../../core/api.service';

interface AuctionEntry {
  id: string;
  status: string;
  item: { name: string; slot: string; tier: string; power: number };
  minPrice: number;
  buyNowPrice: number | null;
  currentBid: number;
  bidCount: number;
  claimed: boolean;
  endsAt: string;
  createdAt: string;
  sellerName: string;
  highestBidderName: string | null;
}

interface Stats {
  active: number;
  sold: number;
  expired: number;
  cancelled: number;
  total_volume: string;
}

@Component({
  selector: 'app-admin-auctions',
  templateUrl: './admin-auctions.component.html',
  styleUrls: ['./admin-auctions.component.scss']
})
export class AdminAuctionsComponent implements OnInit {
  auctions: AuctionEntry[] = [];
  stats: Stats | null = null;

  loading = false;
  error = '';
  success = '';

  statusFilter = 'active';
  page = 1;

  readonly statuses = ['active', 'sold', 'expired', 'cancelled', 'all'];

  constructor(private readonly api: ApiService) {}

  ngOnInit(): void {
    this.loadAuctions();
  }

  setStatus(status: string): void {
    this.statusFilter = status;
    this.page = 1;
    this.loadAuctions();
  }

  prevPage(): void {
    this.page = Math.max(1, this.page - 1);
    this.loadAuctions();
  }

  nextPage(): void {
    this.page += 1;
    this.loadAuctions();
  }

  loadAuctions(): void {
    this.loading = true;
    this.error = '';

    this.api.get<{ auctions: AuctionEntry[]; stats: Stats }>(`/api/admin/auctions?status=${this.statusFilter}&page=${this.page}`).subscribe({
      next: res => {
        this.auctions = res.auctions ?? [];
        this.stats = res.stats ?? null;
        this.loading = false;
      },
      error: err => {
        this.error = err?.error?.error ?? 'Auktionen konnten nicht geladen werden.';
        this.loading = false;
      }
    });
  }

  cancelAuction(id: string): void {
    if (!confirm('Auktion wirklich stornieren und Item zurueckgeben?')) return;

    this.api.delete<{ success: boolean }>(`/api/admin/auctions?id=${id}`).subscribe({
      next: () => {
        this.success = 'Auktion storniert.';
        this.loadAuctions();
      },
      error: err => {
        this.error = err?.error?.error ?? 'Stornieren fehlgeschlagen.';
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
