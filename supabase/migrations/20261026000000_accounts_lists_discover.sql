-- Kelime Widget: optional accounts (Sign in with Apple), synced own lists, Keşfet.
-- Lists carry their cards as a JSON snapshot (the app's SharedList format), so a list opens
-- on any device without the app's content tables on the server.

-- Profiles ------------------------------------------------------------------------------
create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    username text unique check (username ~ '^[a-z0-9_]{3,20}$'),
    display_name text check (char_length(display_name) <= 40),
    avatar text not null default 'letter',
    created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Usernames and avatars appear next to public lists, so profiles are readable by everyone.
create policy "profiles are public" on public.profiles for select using (true);
create policy "own profile insert" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "own profile update" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- A profile row for every new account.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    insert into public.profiles (id) values (new.id) on conflict do nothing;
    return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
    for each row execute function public.handle_new_user();

-- Lists ---------------------------------------------------------------------------------
-- visibility: private (only the owner), link (anyone with the link), public (Keşfet too).
create table public.lists (
    id uuid primary key,
    owner uuid not null references public.profiles (id) on delete cascade,
    title text not null check (char_length(title) between 1 and 40),
    visibility text not null default 'private' check (visibility in ('private', 'link', 'public')),
    cards jsonb not null default '[]'::jsonb,
    word_count integer not null default 0,
    saves integer not null default 0,
    -- Set by reports (see below); hidden lists leave Keşfet and links.
    hidden boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index lists_owner_idx on public.lists (owner);
create index lists_public_idx on public.lists (visibility, hidden, saves desc, updated_at desc);

alter table public.lists enable row level security;

-- Owners see all their lists; everyone else sees public ones. Link lists are read through
-- shared_list(id), never by listing the table.
create policy "own or public lists" on public.lists for select
    using (owner = (select auth.uid()) or (visibility = 'public' and not hidden));
create policy "own list insert" on public.lists for insert to authenticated with check (owner = (select auth.uid()));
create policy "own list update" on public.lists for update to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy "own list delete" on public.lists for delete to authenticated using (owner = (select auth.uid()));

create function public.touch_list() returns trigger
language plpgsql set search_path = '' as $$
begin
    new.updated_at := now();
    new.word_count := coalesce(jsonb_array_length(new.cards), 0);
    return new;
end;
$$;

create trigger lists_touch before insert or update on public.lists
    for each row execute function public.touch_list();

-- Saves (a learner added someone's list) -------------------------------------------------
create table public.list_saves (
    user_id uuid not null references public.profiles (id) on delete cascade,
    list_id uuid not null references public.lists (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_id, list_id)
);

create index list_saves_list_idx on public.list_saves (list_id);

alter table public.list_saves enable row level security;

create policy "own saves" on public.list_saves for all to authenticated
    using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create function public.count_saves() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    update public.lists set saves = (select count(*) from public.list_saves where list_id = coalesce(new.list_id, old.list_id))
    where id = coalesce(new.list_id, old.list_id);
    return null;
end;
$$;

create trigger list_saves_count after insert or delete on public.list_saves
    for each row execute function public.count_saves();

-- Reports and blocks (App Store guideline 1.2 for user content) ---------------------------
create table public.reports (
    id bigint generated always as identity primary key,
    list_id uuid not null references public.lists (id) on delete cascade,
    reporter uuid not null references public.profiles (id) on delete cascade,
    reason text not null check (char_length(reason) <= 200),
    created_at timestamptz not null default now(),
    unique (list_id, reporter)
);

alter table public.reports enable row level security;

-- Anyone signed in may report; nobody reads reports through the API (review them in the dashboard).
create policy "report a list" on public.reports for insert to authenticated with check (reporter = (select auth.uid()));

-- Three different reporters hide a list until it is reviewed.
create function public.hide_reported() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
    if (select count(*) from public.reports where list_id = new.list_id) >= 3 then
        update public.lists set hidden = true where id = new.list_id;
    end if;
    return null;
end;
$$;

create trigger reports_hide after insert on public.reports
    for each row execute function public.hide_reported();

create table public.blocks (
    blocker uuid not null references public.profiles (id) on delete cascade,
    blocked uuid not null references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker, blocked)
);

alter table public.blocks enable row level security;

create policy "own blocks" on public.blocks for all to authenticated
    using (blocker = (select auth.uid())) with check (blocker = (select auth.uid()));

-- Functions the app calls ---------------------------------------------------------------
-- Keşfet: public lists, newest or most saved, matching an optional search, without the lists
-- of people the caller blocked.
create function public.discover(search text default '', sort text default 'popular', page_size integer default 30, page integer default 0)
returns table (
    id uuid, title text, word_count integer, saves integer, updated_at timestamptz,
    owner uuid, username text, display_name text, avatar text
)
language sql stable security invoker set search_path = '' as $$
    select l.id, l.title, l.word_count, l.saves, l.updated_at, p.id, p.username, p.display_name, p.avatar
    from public.lists l
    join public.profiles p on p.id = l.owner
    where l.visibility = 'public' and not l.hidden
      and (search = '' or l.title ilike '%' || search || '%')
      and not exists (select 1 from public.blocks b where b.blocker = (select auth.uid()) and b.blocked = l.owner)
    order by case when sort = 'new' then null else l.saves end desc nulls last, l.updated_at desc
    limit least(greatest(page_size, 1), 50) offset greatest(page, 0) * least(greatest(page_size, 1), 50);
$$;

-- A list opened from a link (or Keşfet): public and link lists, or the caller's own.
create function public.shared_list(list_id uuid)
returns table (id uuid, title text, cards jsonb, word_count integer, saves integer, owner uuid, username text, display_name text, avatar text)
language sql stable security definer set search_path = '' as $$
    select l.id, l.title, l.cards, l.word_count, l.saves, p.id, p.username, p.display_name, p.avatar
    from public.lists l
    join public.profiles p on p.id = l.owner
    where l.id = list_id
      and (l.owner = (select auth.uid()) or (l.visibility in ('public', 'link') and not l.hidden));
$$;

-- Deletes the caller's account and everything they own (App Store guideline 5.1.1(v)).
create function public.delete_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
    delete from auth.users where id = (select auth.uid());
end;
$$;

revoke execute on function public.delete_account() from anon, public;
grant execute on function public.delete_account() to authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated, public;
revoke execute on function public.count_saves() from anon, authenticated, public;
revoke execute on function public.hide_reported() from anon, authenticated, public;
