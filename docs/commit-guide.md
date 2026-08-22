# Commit & Push Guide — TriGo System

How this repo is committed and pushed: group changes by common theme, verify the
staged set, commit with conventional messages, then push.

This is a **monorepo**: one git repo holds three apps —

- `apps/trigo-backend` — Express.js API
- `apps/trigo-admin` — Vue 3 admin panel
- `apps/trigo` — Flutter mobile app

A single feature usually touches more than one app, so commits are grouped by
**feature area**, not by app.

---

## 1. Inspect Before Committing

Run from the repo root (Windows PowerShell):

```powershell
git status
git diff --stat        # sizes per file, reveals dominant themes
git log --oneline -10  # match the repo's existing message style
```

Read the actual diffs of ambiguous files before assigning them to a group:

```powershell
git diff "apps/trigo-backend/src/features/drivers/drivers.service.ts"
```

## 2. Group Changes by Common Theme

- **One commit per theme**, not per file. Assign each file by its
  **dominant theme**; if a file mixes themes, it goes with the primary intent
  (do not hunk-split unless a file truly spans features).
- **Never mix**: new feature code + unrelated type cleanup + docs in one commit.
- **Keep migration changes with their schema change**:
  `apps/trigo-backend/src/shared/database/migrate.ts` belongs in the same
  commit as the feature whose schema it migrates.
- **Exclude artifacts**: `node_modules/`, `dist/`, `build/`, `.env*`,
  `.dart_tool/`, `ios/Pods/`, `apps/trigo-backend/uploads/` (runtime user
  documents) are all gitignored. Leave them untracked.
- **Leave `.opencode/` untracked** — local scratch, not source.
- **Keep the index clean between commits**: after each commit, re-check
  `git status` so no file is silently left out.

Typical theme buckets used in this repo (scope = feature area, not app):

| Prefix | Scope | Example message |
|--------|-------|-----------------|
| `feat` | drivers | `feat(drivers): application review lifecycle` |
| `feat` | uploads | `feat(uploads): document uploads + serving` |
| `feat` | auth | `feat(auth): split passenger/driver registration` |
| `feat` | admin | `feat(admin): applications list with review actions` |
| `feat` | rides | `feat(rides): pickup flow status polling` |
| `fix` | auth | `fix(auth): PIN session expiry edge case` |
| `refactor` | api | `refactor(api): consolidate feature routing` |
| `chore` | docs | `chore: docs and housekeeping` |

## 3. Stage Files

Source paths in this repo are plain (no `(`, `[`, `]`, or spaces), so a normal
pathspec works:

```powershell
git add apps/trigo-backend/src/features/uploads/ apps/trigo/lib/features/driver_application/
git add apps/trigo-admin/src/features/driver-applications/DriverApplicationsList.vue
```

For large groups, write the file list to a temp file and stage in one shot:

```powershell
# list one path per line in commit1.txt
$files = Get-Content "$env:TEMP\commit1.txt"
git add -- $files
```

Verify the staged set matches exactly (catches typos and look-alike paths):

```powershell
$staged   = git diff --cached --name-only
$expected = Get-Content "$env:TEMP\commit1.txt"
"staged: $($staged.Count) expected: $($expected.Count)"
"missing:"; $expected | Where-Object { $_ -notin $staged }
"extra:";   $staged   | Where-Object { $_ -notin $expected }
```

Then re-check `git status` after committing so leftovers surface immediately.

## 4. Commit Message Format

Subject: `type(scope): summary` — imperative, ≤ ~72 chars.
Body: bullet points describing what changed and why.

```powershell
git commit -m "feat(drivers): application review lifecycle

- Add pending -> reviewing -> approved/rejected status transitions
- Guard resubmission with allowlist of resubmittable fields
- Wire review actions into drivers router and admin panel"
```

One `git commit` per group; do not stage the next group until the current
commit is created.

## 5. Verify Before/After Committing

```powershell
npm run lint            # eslint on backend + admin
npm run test:backend    # vitest run (backend)
npm run build:backend   # tsc --noEmit equivalent (tsc emit)
npm run build:admin     # vue-tsc + vite build
cd apps/trigo; flutter analyze; flutter test
git status              # should only show the files you intend to commit
```

Run the gates that apply to the group being committed. After all groups,
`git log --oneline` should read as a clean story, and `git status` should be
clean except for intentional leftovers (e.g. scratch notes).

## 6. Push

The current branch `dev` tracks `origin/dev`, so a plain push works:

```powershell
git push
```

**Before pushing, always confirm with the user and show the commit summary:**

1. Show what would be pushed — the ahead count plus the commits:
   ```powershell
   git status                              # confirm ahead count matches
   git log --oneline origin/dev..HEAD      # exact commits that will go out
   ```
2. Present that summary to the user and ask for confirmation
   (e.g. "push N commits to origin/dev?").
3. **Only run `git push` after the user confirms.** Commits stay local until
   then; never push unprompted.

Note: `main` is a separate branch that also tracks `origin/main`; push it
explicitly (`git push origin main`) only when asked.

## 7. Pitfalls Learned (Windows)

- **LF → CRLF warnings**: `warning: LF will be replaced by CRLF` is harmless
  (core.autocrlf) — ignore it.
- **Gitignored paths**: a tracked file inside a gitignored dir still stages
  normally; an **untracked** file there needs `git add -f`. Keep `.env`,
  `node_modules/`, `dist/`, and `build/` in `.gitignore` so local state never
  gets committed.
- **Build output**: `dist/` and Flutter `build/` are generated and gitignored —
  never force-add them.
- **Runtime uploads**: `apps/trigo-backend/uploads/` holds uploaded documents
  at runtime; it is gitignored and must never be committed.
- **Push only when asked**: commits stay local until the user requests a push.

---

### Worked Example

The driver registration split plus document uploads was split into four
commits:

```
abc1234 feat(auth): split passenger/driver registration
def5678 feat(uploads): document uploads + serving
9ab0cde feat(drivers): application review lifecycle
fed1234 feat(admin): applications list with review actions
```

Each commit mixed backend, Flutter, and/or admin files freely because the scope
is the feature area, not the app. The `chore` commit is omitted here because
the doc update was folded into its own commit on a later pass — exactly the
leftover `git status` re-check from §2/§3 is meant to catch.