# Lanka Jobs 🇱🇰

Collects software engineering, IT, internship and associate/junior jobs in Sri Lanka from:

- **topjobs.lk** (IT software + IT hardware/networks categories)
- **xpress.jobs** (IT software, IT hardware, internship sectors)
- **itpro.lk**
- **jobhub.lk** (filtered to tech roles)
- **LinkedIn** (public Sri Lanka job search)
- **Company career pages** (WSO2, Sysco LABS, 99x, IFS, Virtusa, Calcey, …). Add more from the Sources page; Lever, Greenhouse, Workable, SmartRecruiters, Recruitee and plain career pages all work.

It runs every 5 minutes (Supabase `pg_cron` calls `/api/cron`) and sends new jobs to Telegram.
"Mark applied" saves the job description so you can read it later on **My applications**.

## Stack
Next.js 15 (Vercel) · Supabase Postgres (schema `lankajobs`) · Telegram Bot API

## Environment variables
| Name | Purpose |
|---|---|
| `DATABASE_URL` | Supabase pooler connection string (role `jobs_app`) |
| `CRON_SECRET` | Secret the scheduler sends to `/api/cron?key=…` |
| `APP_PASSWORD` | Password for the website |
| `SITE_URL` | Public URL, used in Telegram messages |

The Telegram bot token is set on the Settings page, not in an env var.
