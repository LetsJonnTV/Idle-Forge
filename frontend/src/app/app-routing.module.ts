import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { LandingComponent }   from './pages/landing/landing.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { AdminComponent }     from './pages/admin/admin.component';
import { WikiComponent }      from './pages/wiki/wiki.component';
import { AuthGuard }  from './guards/auth.guard';
import { AdminGuard } from './guards/admin.guard';

const routes: Routes = [
  { path: '',          component: LandingComponent },
  { path: 'wiki',      component: WikiComponent },
  { path: 'dashboard', component: DashboardComponent, canActivate: [AuthGuard] },
  { path: 'admin',     component: AdminComponent,     canActivate: [AuthGuard, AdminGuard] },
  { path: '**',        redirectTo: '' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes, { scrollPositionRestoration: 'top' })],
  exports: [RouterModule]
})
export class AppRoutingModule { }
