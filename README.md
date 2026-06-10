# Gowai — AI Travel Planner

A production-ready Flutter app that uses Claude AI to generate personalized full-day trip itineraries, displays them on Google Maps with route lines, and saves trips to Supabase.

## Screenshots

| Onboarding | Planner | Itinerary | History |
|---|---|---|---|
| *(screenshot)* | *(screenshot)* | *(screenshot)* | *(screenshot)* |

## Features

- **AI Trip Generation** — Claude Sonnet 4 crafts a personalized 5-7 stop itinerary based on your vibe, budget, group, and transport preferences
- **Google Maps** — Live map with numbered markers and polyline route connecting all stops
- **Place Photos & Details** — Powered by Google Places API
- **Save & Share** — Store trips to Supabase and share via public link (no login needed for viewers)
- **Trip History** — Grid of all past trips with cover photos
- **Freemium** — 3 free trips/month; unlimited with Pro (RevenueCat)
- **Auth** — Email/password via Supabase Auth

## Setup

### 1. Clone the repository
```bash
git clone <repo-url>
cd trip_mind_app
```

### 2. Create `.env` file
Create a `.env` file in the project root (never commit this):
```
ANTHROPIC_API_KEY=your_key_here
GOOGLE_MAPS_API_KEY=your_key_here
GOOGLE_PLACES_API_KEY=your_key_here
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
REVENUECAT_API_KEY=your_rc_key_here
```

### 3. Install dependencies
```bash
flutter pub get
```

### 4. Run the app
```bash
flutter run
```

## API Keys

| Key | Where to get |
|---|---|
| `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com) |
| `GOOGLE_MAPS_API_KEY` | [Google Cloud Console](https://console.cloud.google.com) — enable Maps SDK for Android, Maps SDK for iOS, Directions API |
| `GOOGLE_PLACES_API_KEY` | Same project — enable Places API |
| `SUPABASE_URL` + `SUPABASE_ANON_KEY` | [app.supabase.com](https://app.supabase.com) → Project Settings → API |
| `REVENUECAT_API_KEY` | [app.revenuecat.com](https://app.revenuecat.com) |

## Supabase Database Setup

Run the following SQL in your Supabase SQL editor:

```sql
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  full_name text,
  avatar_url text,
  trips_used_this_month integer default 0,
  last_reset_date date default current_date,
  is_pro boolean default false,
  created_at timestamp with time zone default now()
);

create table trips (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade,
  destination text not null,
  trip_date date,
  vibe text,
  budget text,
  group_type text,
  itinerary_json jsonb not null,
  is_public boolean default false,
  share_token text unique,
  created_at timestamp with time zone default now()
);

alter table profiles enable row level security;
alter table trips enable row level security;

create policy "Users can view own profile" on profiles for select using (auth.uid() = id);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);
create policy "Users can view own trips" on trips for select using (auth.uid() = user_id);
create policy "Users can insert own trips" on trips for insert with check (auth.uid() = user_id);
create policy "Users can delete own trips" on trips for delete using (auth.uid() = user_id);
create policy "Anyone can view public trips" on trips for select using (is_public = true);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

## Project Structure

```
lib/
  main.dart                    ← App entry point
  app.dart                     ← GoRouter + MaterialApp
  core/
    constants/                 ← Colors, strings, API endpoints
    models/                    ← Trip, TripStop, UserProfile
    services/                  ← Claude, Places, Directions, Supabase, RevenueCat
    theme/                     ← AppTheme (Poppins + custom colors)
    utils/                     ← ErrorHandler, JsonParser
  features/
    onboarding/                ← 3-slide onboarding
    auth/                      ← Login + Signup screens
    planner/                   ← Conversational question flow
    itinerary/                 ← Map + stop cards result screen
    history/                   ← Saved trips grid
    profile/                   ← User stats + upgrade + sign out
    shared_trip/               ← Public read-only itinerary view
    subscription/              ← RevenueCat paywall
  shared/widgets/              ← PrimaryButton, BottomNav, etc.
```

## Tech Stack

- **Flutter** + Dart
- **Claude Sonnet 4** (Anthropic) — AI trip generation
- **Google Maps Flutter** — Map rendering + routes
- **Google Places API** — Place photos + coordinates
- **Supabase** — Auth + PostgreSQL database
- **RevenueCat** — In-app purchases
- **Riverpod** — State management
- **GoRouter** — Navigation + deep links
- **flutter_animate** — Smooth animations
