import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { LandingComponent }   from './pages/landing/landing.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { AdminComponent }     from './pages/admin/admin.component';
import { WikiComponent }      from './pages/wiki/wiki.component';
import { InventoryComponent } from './pages/inventory/inventory.component';
import { LoginComponent } from './pages/login/login.component';
import { AdminEventsComponent } from './pages/admin-events/admin-events.component';
import { AdminAuctionsComponent } from './pages/admin-auctions/admin-auctions.component';
import { AdminClanWarsComponent } from './pages/admin-clan-wars/admin-clan-wars.component';
import { AuthGuard }  from './guards/auth.guard';
import { AdminGuard } from './guards/admin.guard';

const routes: Routes = [
  { path: '',          component: LandingComponent },
  { path: 'login',     component: LoginComponent },
  { path: 'wiki',      component: WikiComponent },
  { path: 'dashboard', component: DashboardComponent, canActivate: [AuthGuard] },
  { path: 'inventory', component: InventoryComponent, canActivate: [AuthGuard] },
  { path: 'admin',     component: AdminComponent,     canActivate: [AuthGuard, AdminGuard] },
  { path: 'admin/events', component: AdminEventsComponent, canActivate: [AuthGuard, AdminGuard] },
  { path: 'admin/auctions', component: AdminAuctionsComponent, canActivate: [AuthGuard, AdminGuard] },
  { path: 'admin/clan-wars', component: AdminClanWarsComponent, canActivate: [AuthGuard, AdminGuard] },
  { path: '**',        redirectTo: '' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes, { scrollPositionRestoration: 'top' })],
  exports: [RouterModule]
})
export class AppRoutingModule { }
