-- Covering indexes for the foreign keys the advisor flagged (account deletion cascades through them).
create index blocks_blocked_idx on public.blocks (blocked);
create index reports_reporter_idx on public.reports (reporter);
