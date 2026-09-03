# PBSci Faculty Recruitment Event Signup

A small multiuser R Shiny application designed for **Posit Connect Cloud Free** with **Supabase Free** as persistent storage.

## What it does

- Shows eleven Fall 2026 / Spring 2027 recruitment, yield, and commencement sessions.
- Provides two faculty positions per session.
- Lets faculty claim the next open position with a last name.
- Makes claimed positions read-only and visibly filled.
- Prevents simultaneous users from overbooking an event.
- Allows a signup to be removed after confirmation.
- Refreshes automatically every 15 seconds and on demand.
- Summarizes filled and remaining positions.

## 1. Create the Supabase database

1. Create a free project at Supabase.
2. Open **SQL Editor**, choose **New query**, paste the complete contents of `supabase_setup.sql`, and select **Run**.
3. In **Project Settings → Data API**, copy:
   - Project URL
   - anon/public key (a publishable key also works if Supabase labels it that way)

The SQL file creates the tables, safe two-slot transaction, public policies, and all initial events. Running it again resets the event list and deletes existing signups, so use it only for initial setup or an intentional reset.

For an existing deployment, run `add_commencement_events.sql` once to add the Fall 2026 and Spring 2027 commencement events without affecting existing signups.

## 2. Test locally in RStudio

Install packages once:

```r
install.packages(c("shiny", "bslib", "httr2", "jsonlite", "rsconnect"))
```

Create a local `.Renviron` file in the project directory (do not publish it):

```text
SUPABASE_URL=https://YOUR-PROJECT.supabase.co
SUPABASE_ANON_KEY=YOUR-ANON-OR-PUBLISHABLE-KEY
```

Restart R, open `app.R`, and select **Run App**.

## 3. Publish to Posit Connect Cloud

1. Put these project files in a public GitHub repository. Do **not** commit `.Renviron`.
2. Sign in to Posit Connect Cloud and create a new Shiny deployment from that repository.
3. Add these environment variables/secrets to the deployment:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
4. Deploy with `app.R` as the primary file.
5. Keep the resulting URL unlisted and distribute it only to faculty.

The app never writes to the Posit filesystem; all signup state lives in Supabase and therefore survives restarts and redeployments.

## Important operating notes

- This version intentionally has no authentication, as requested. Anyone with the URL can enter or remove a last name.
- Keeping the URL unlisted reduces casual discovery but is not access control.
- Names and event assignments are visible to anyone with the URL.
- The anon/publishable key is not treated as a secret security boundary here; the database policies deliberately allow the app's public operations.
- Supabase Free may pause after inactivity. Opening the app/project may require a short wake-up delay.

## Editing events later

Use Supabase **Table Editor → events**. You can change event text, dates, locations, or `slots_required` without republishing the Shiny app. For an Explore UNF schedule expander, set `details_key` to `explore`; otherwise leave it blank.

## Project files

- `app.R` — Shiny interface and server logic
- `R/supabase.R` — Supabase REST functions
- `www/styles.css` — responsive visual design
- `supabase_setup.sql` — schema, policies, atomic signup function, and seeded events
