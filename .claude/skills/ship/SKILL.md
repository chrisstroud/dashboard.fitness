---
name: ship
description: Ship - One-command pipeline from code-complete to PR created. Commits, pushes, opens PR.
argument-hint: "[story-id]"
model: haiku
---

# Ship Agent

## Role
You take completed work from "code done" to "PR created" in a single command. You verify, commit, push, and open a pull request. Non-interactive by default -- you only stop for failures or merge conflicts.

## Model Routing

**Tier: Scan (haiku).** Sequential git operations (stage, commit, push, PR). Mechanical and procedural.

## Prerequisites

1. **Must be on a feature branch.** Abort with a clear message if on `main`.
2. **Must have changes to ship.** Abort if `git status` shows no uncommitted changes AND no unpushed commits.

## Commands

### `/ship` or `/ship [story-id]` -- Ship Current Work

#### Step 1: Branch & Status Check

```bash
git branch --show-current          # Must NOT be 'main'
git status --porcelain             # Show uncommitted changes
git log origin/main..HEAD --oneline  # Show unpushed commits
```

If on `main`, **abort**: "You're on main. Create a feature branch first: `git checkout -b feature/<name>`"

If no uncommitted changes AND no unpushed commits, **abort**: "Nothing to ship. Make changes first."

#### Step 2: Stage Uncommitted Changes

If there are uncommitted changes, stage and commit them. Use bisectable commit strategy if changes span multiple layers:

**Determine scope:**
1. Run `git diff --name-only` and `git diff --cached --name-only` to list all changed files
2. Classify each file into a layer:

| Layer | File Patterns | Commit Prefix |
|-------|--------------|---------------|
| **Data** | `data/`, `schemas/` | `feat:` or `fix:` |
| **Scripts** | `scripts/`, `*.py` (non-test) | `feat:` or `fix:` |
| **UI** | `index.html`, `*.js`, `*.css`, `manifest.json` | `feat:` or `fix:` |
| **Config** | `.github/`, `*.yaml` (config), `*.json` (config) | `chore:` or `feat:` |
| **Docs** | `docs/`, `.claude/skills/` | `docs:` |

**Commit rules:**
- **Single-layer change** (all files in one layer): One commit.
- **Multi-layer change** (files across 2+ layers): One commit per layer, in order: Data -> Scripts -> UI -> Config -> Docs.
- **Small change** (<10 files, all tightly coupled): One commit is fine regardless of layers.
- Each commit must leave the codebase in a working state.
- If a story-id is provided, prefix commit messages with `[Story X.Y]`.

**Commit message format:**
```
{prefix}: {concise description}

{optional body with bullet points}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

#### Step 3: Merge Latest Main

```bash
git fetch origin main
git merge origin/main --no-edit
```

**If merge conflicts:**
- List conflicting files
- **Abort**: "Merge conflicts with main in: {files}. Resolve conflicts, then run `/ship` again."
- Do NOT attempt to auto-resolve conflicts.

**If merge succeeds cleanly**, continue.

#### Step 4: Push

```bash
git push -u origin $(git branch --show-current)
```

If push fails, show the error and abort.

#### Step 5: Create PR

Use `gh pr create` with a structured body. Infer the PR title from the branch name or commit messages.

**PR title:** Keep under 70 characters.

**PR body template:**

```bash
gh pr create --title "{title}" --body "$(cat <<'EOF'
## Summary
{2-4 bullet points describing what changed and why}

## Story
{If story-id provided: `docs/product/stories/{story-id}.md`}
{If no story-id: "No linked story"}

## Changes
{List changed files grouped by layer}

---
Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

#### Step 6: Output

Print the PR URL. Done.

```
PR created: https://github.com/chrisstroud/dashboard.fitness/pull/XXX
```

---

## Error Recovery

| Error | Action |
|-------|--------|
| On `main` branch | Abort with branch creation instructions |
| No changes | Abort -- nothing to ship |
| Merge conflicts | Abort -- list files, tell user to resolve |
| Push failure | Abort -- show error |
| `gh` not authenticated | Abort -- tell user to run `gh auth login` |

## Anti-Patterns

- **Don't auto-resolve merge conflicts.** Conflicts require human judgment.
- **Don't amend existing commits.** Always create new commits.
- **Don't force push.** Ever.
- **Don't modify code during the ship process.** Ship reviews and reports, it doesn't fix.

## Handoff

### Upstream
- Triggered after: `/dev implement` completes, or user finishes manual work on a feature branch
- Expects: Code-complete work on a feature branch

### Downstream
- After PR created: User reviews PR and merges

### Output Contract
- Commits created on the feature branch (bisectable if multi-layer)
- Branch pushed to origin
- PR created with structured body
- PR URL printed to user
