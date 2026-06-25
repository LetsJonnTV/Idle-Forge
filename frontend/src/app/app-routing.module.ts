import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { LandingComponent }       from './pages/landing/landing.component';
import { DashboardComponent }     from './pages/dashboard/dashboard.component';
import { WikiComponent }          from './pages/wiki/wiki.component';
import { InventoryComponent }     from './pages/inventory/inventory.component';
import { LoginComponent }         from './pages/login/login.component';
import { AdminShellComponent }    from './components/admin-shell/admin-shell.component';
import { AdminComponent }         from './pages/admin/admin.component';
import { AdminEventsComponent }   from './pages/admin-events/admin-events.component';
import { AdminAuctionsComponent } from './pages/admin-auctions/admin-auctions.component';
import { AdminClanWarsComponent } from './pages/admin-clan-wars/admin-clan-wars.component';
import { AdminClansComponent }    from './pages/admin-clans/admin-clans.component';
import { AuthGuard }              from './guards/auth.guard';
import { AdminGuard }             from './guards/admin.guard';

const routes: Routes = [
  { path: '',          component: LandingComponent },
  { path: 'login',     component: LoginComponent },
  { path: 'wiki',      component: WikiComponent },
  { path: 'dashboard', component: DashboardComponent, canActivate: [AuthGuard] },
  { path: 'inventory', component: InventoryComponent, canActivate: [AuthGuard] },
  {
    path: 'admin',
    component: AdminShellComponent,
    canActivate: [AuthGuard, AdminGuard],
    children: [
      { path: '',         component: AdminComponent },
      { path: 'events',   component: AdminEventsComponent },
      { path: 'auctions', component: AdminAuctionsComponent },
      { path: 'clan-wars', component: AdminClanWarsComponent },
      { path: 'clans',    component: AdminClansComponent },
    ]
  },
  { path: '**', redirectTo: '' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes, { scrollPositionRestoration: 'top' })],
  exports: [RouterModule]
})
export class AppRoutingModule { }
