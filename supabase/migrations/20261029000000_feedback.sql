-- In-app feedback: card error reports and suggestions. Anyone may send; nobody reads through
-- the API (no select policy). Read them in the dashboard.
create table public.feedback (
    id bigint generated always as identity primary key,
    kind text not null check (kind in ('card', 'suggestion')),
    card_id text check (char_length(card_id) <= 80),
    word text check (char_length(word) <= 120),
    reason text check (char_length(reason) <= 60),
    note text check (char_length(note) <= 1000),
    app_version text check (char_length(app_version) <= 40),
    user_id uuid default auth.uid() references auth.users (id) on delete set null,
    created_at timestamptz not null default now()
);

alter table public.feedback enable row level security;

create policy "anyone can send feedback" on public.feedback
    for insert to anon, authenticated
    with check (user_id is null or user_id = auth.uid());

create index feedback_user_idx on public.feedback (user_id);

grant insert on public.feedback to anon, authenticated;
