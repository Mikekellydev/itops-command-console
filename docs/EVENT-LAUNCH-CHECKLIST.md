# Event Launch Checklist

Use this before pushing the repo link out publicly.

## Final Repo Check

1. Run `git status --short` and confirm only intentional code, docs, and `.gitkeep` changes are staged.
2. Confirm the repo is no longer tracking:
   `95_Tools/dashboard/.venv/`, `80_Time/DB/`, `20_Areas/Daily/*.md`, and live `10_Tickets/*/*/`.
3. Verify `README.md` is accurate for the flow you want to demo.

## Functional Smoke Test

1. Run `./install.sh` on a clean Ubuntu or WSL environment if possible.
2. Run `itnew` and create a test record.
3. Run `itdash` and verify search, `Enter`, `n`, `h`, `x`, and `c`.
4. Run `itops_ent` and confirm the tmux layout opens correctly.

## Public Links

1. Push the repo.
2. If using GitHub Pages, publish `docs/website/`.
3. Confirm the website and repository link to each other correctly.

## Demo Talking Points

- local-first operations workflow
- explicit SQLite-backed lifecycle control
- terminal UI for queue management
- Markdown artifacts for durable operational notes
- clean separation between tracked source and local runtime data
