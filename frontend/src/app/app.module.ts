import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';

// Components
import { HeaderComponent }    from './components/header/header.component';
import { AuthModalComponent } from './components/auth-modal/auth-modal.component';

// Pages
import { LandingComponent }   from './pages/landing/landing.component';
import { DashboardComponent } from './pages/dashboard/dashboard.component';
import { AdminComponent }     from './pages/admin/admin.component';
import { WikiComponent }      from './pages/wiki/wiki.component';
import { InventoryComponent } from './pages/inventory/inventory.component';
import { LoginComponent } from './pages/login/login.component';
import { AdminEventsComponent } from './pages/admin-events/admin-events.component';
import { AdminAuctionsComponent } from './pages/admin-auctions/admin-auctions.component';
import { AdminClanWarsComponent } from './pages/admin-clan-wars/admin-clan-wars.component';

@NgModule({
  declarations: [
    AppComponent,
    HeaderComponent,
    AuthModalComponent,
    LandingComponent,
    DashboardComponent,
    AdminComponent,
    WikiComponent,
    InventoryComponent,
    LoginComponent,
    AdminEventsComponent,
    AdminAuctionsComponent,
    AdminClanWarsComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    HttpClientModule,
    FormsModule,
    ReactiveFormsModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
