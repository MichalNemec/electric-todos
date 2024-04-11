-- migrate:up
ALTER TABLE IF EXISTS public.todo
ADD COLUMN owner text;

-- migrate:down

ALTER TABLE IF EXISTS public.todo
REMOVE COLUMN owner;
