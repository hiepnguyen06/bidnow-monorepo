# BidNow Monorepo Restructure: Design

Date: 2026-10-22

## Intent and why

BidNow is split today into `backend/` (Maven multi-module, 8 Spring Boot services plus 2 shared modules) and `frontend/` (one Next.js app), with `docs/`, `docker/`, a root `docker-compose.yml` and `.github/` at the root. The owner wants one repository, `bidnow-monorepo`, on their own GitHub account, laid out so that **more services, more apps, AI integrations and MCP servers can be added later without reshuffling folders**. They will also manage AWS infrastructure with Terraform later.

A second driver: the live app will not stay up long because of cost. A small **landing/showcase site** (tech stack, architecture, features) must outlive it so potential employers can see the project. The repo itself will be public for the same audience.

This task is only the **folder restructure, the repo move, and the landing app**. It is not an infra build.

## Goals

1. New public GitHub repo `bidnow-monorepo`, with **full git history carried over** (moves are plain `git mv`, so history follows the files).
2. Folder layout below, with everything still building, testing and running locally after the move.
3. CI workflows, Dockerfile contexts, docker-compose paths, Dependabot config and docs updated to the new paths. Nothing silently left pointing at `backend/` or `frontend/`.
4. A new `apps/landing/` static site containing the architecture showcase moved out of the web app.
5. An empty, documented `infra/terraform/` ready for the owner to fill later.

## Non-goals

- Writing any Terraform, choosing ECS/EKS/serverless, or any AWS decision. The owner decides later.
- Creating AI/MCP folders or code. The owner has nothing in mind yet. New top-level folders are added the day they are needed.
- A monorepo build tool (Nx, Turborepo, pnpm workspaces). Plain folders with per-folder CI.
- Changing service behavior, APIs, databases or package names.
- Deploying the landing site (hosting choice and its pipeline come later).

## Anti-goals (would be a failure even if it technically works)

- Losing history, or pushing secrets to a public repo.
- Moving files in a way that breaks rename detection (e.g. moving and heavily editing in the same commit).
- Leaving CI green only because path filters now match nothing.

## Target layout

```
bidnow-monorepo/
├── apps/
│   ├── web/              ← today's frontend/ (Next.js main app)
│   └── landing/          ← NEW: static showcase site
├── services/             ← today's backend/ (Maven parent pom stays here)
│   ├── pom.xml
│   ├── api-gateway/ discovery-service/ identity-service/ user-service/
│   ├── auction-service/ bidding-service/ wallet-service/ media-service/
│   └── common/ bdd-support/   ← shared Java modules, kept beside services
├── infra/
│   ├── terraform/        ← empty, with a short README only
│   └── local/            ← docker-compose.yml + postgres init (dev only)
├── docs/                 ← single docs folder (backend/docs merged in)
├── .github/              ← workflows, dependabot, templates, updated paths
└── README.md, AGENTS.md, CONTRIBUTING.md, DESIGN.md
```

Reasoning behind it:
- `apps/` = things a user opens. `services/` = things that run behind the gateway.
- `common` and `bdd-support` are Maven modules tied to the parent pom, so they stay in `services/`. A top-level `libs/` for non-Java shared code is added later only if needed.
- No empty placeholder folders except `infra/terraform/`, which the owner explicitly wants as a home.

## Landing app

- `apps/landing/`: Next.js with static export, same stack as the web app so existing components, Tailwind setup and the `lib/about.ts` content can be reused. No dependency on any backend.
- Content: the architecture showcase page currently at `frontend/app/about/` (plus `lib/about.ts` and its test, and whatever shared components it needs). That content is **removed from the web app**.
- The web app's navbar/footer links that point to `/about` become external links to the landing site. The URL does not exist yet, so the builder uses a single configurable constant (env var with a placeholder default), not a hard-coded host.
- Landing gets its own CI job (build + lint, plus the moved test).

## Decisions and who made them

Decided by the owner:
- Monorepo named `bidnow-monorepo`, public, history carried over.
- AWS + Terraform later; Terraform is not part of this work.
- AI/MCP left out for now.
- Landing page is part of this work; the architecture showcase moves from the web app into it.

My calls (owner can override):
- Folder names `apps/`, `services/`, `infra/`, and keeping `common`/`bdd-support` inside `services/`.
- Dropping the empty `rules/` folder (the `common-resources` removal is the owner's decision, see below).
- Merging the duplicate `backend/docker-compose.yml` into `infra/local/`, and `backend/docs/` into `docs/`.
- No monorepo build tool.
- Landing app stack: Next.js static export.
- Pushing only `main` and `develop` (plus tags) to the new repo. Other local branches are mostly merged into main already and stay local.
- Do the restructure on a new branch `refactor/monorepo-structure`, in a few reviewable commits (moves only, then path fixes, then landing app), using conventional commits per CONTRIBUTING.md. No commits are made until the owner asks.

Decided by the owner, after the builder check:
- **Branch tip:** the restructure starts from the current branch `feature/browse-redesign` (it contains `develop` and the showcase page). The restructured result is pushed as the new repo's `main`; the old `main` history is included in it.
- **GitHub owner:** `hiepnguyen06`, so the repo is `hiepnguyen06/bidnow-monorepo`.
- **No Dependabot:** no `dependabot/*` branches are pushed (only `main` and `develop` go up, plus tags). `.github/dependabot.yml` and `.github/workflows/dependabot-auto-merge.yml` are deleted in the new repo, and any other reference to Dependabot in CI or docs is removed.
- **`common-resources` removed:** the submodule, `.gitmodules` and every mention of `/common-resources` (including the "Review Existing Context" directive in AGENTS.md) are removed.

- **No Claude in contributors:** the `Co-Authored-By: Claude ...` trailers (12 commits) are stripped from commit messages before the push. Done in a scratch clone so the working repo and the old repo are untouched. This rewrites those commits and their descendants (new hashes in the new repo); file contents are unchanged. The earlier "history as is" decision still holds otherwise. The Neon password stays in history; the owner rotates it.

More calls of mine, from the builder check (owner can override):
- **`/about` in the web app:** it redirects to the landing site. The navbar and footer "About" links stay and point to the landing URL, read from `NEXT_PUBLIC_LANDING_URL` (placeholder default until the real host exists).
- **Landing is self-contained:** it copies the components, Tailwind setup and design tokens it needs. No shared package, so the two apps may drift, which is acceptable for a showcase.
- **CI and deploy:** `cd-deploy.yml` stays disabled (it already has `if: false`) with paths updated. Workflows get path filters so each runs for its own folder, and the builder checks that each filter matches real files.
- **Compose:** the root `docker-compose.yml` wins. The builder diffs it against `backend/docker-compose.yml` and carries over only services or env vars the root file lacks.
- **Secret scan bar:** only real credentials count as a finding (stop and ask). Local-dev defaults such as `bidnow/bidnow` and `.env.example` placeholders are fine. The builder reads `docs/secret/configuration_management_guide.md` and reports whether it holds real values or only documentation.
- **`.agent/`, `.claude/`, `.superpowers/`, `docs/superpowers/`:** left as they are tracked today; the scan decides if anything must go.
- **Other branches and worktrees:** other local branches and the worktrees under `.claude/worktrees` are not touched or rebased. They stay in the old repo's world.
- The old repo's issues, PRs and Dependabot history do not carry over.

## Constraints

- Public repo: **scan the whole history for secrets** (API keys, passwords, `.env` contents, anything in `docs/secret/`) before the first push. If something is found, stop and ask the owner: rewriting history changes the "carry over" promise.
- `origin` currently points at `KhoaLy2003/bidnow`. The new repo is added as a new remote, and nothing is pushed to the old one.
- Pushing, repo creation on GitHub and visibility are outward-facing: the builder confirms with the owner right before doing them.
- AGENTS.md rules still apply (docs must be updated when the structure changes; no destructive operations without approval).
- Windows + OneDrive working directory: moves should use `git mv`, and file locks from IDE/dev servers (`node_modules`, `.next`) may get in the way.

## Left to the builder

- Exact CI path filters and job layout, as long as each workflow still runs for its own folder.
- Dockerfile and compose path fixes.
- Whether `.agent/`, `.claude/` and `.superpowers/` stay as is (they are partly gitignored).
- README rewrite for the new layout, and the Terraform README wording.
- How to split work into commits.

## Done looks like

- `services/` builds with Maven; `apps/web` and `apps/landing` build, lint and pass their tests.
- `docker compose` from `infra/local/` brings the local stack up with the new paths.
- No remaining references to old `backend/` or `frontend/` paths in workflows, Dockerfiles, compose, Dependabot, AGENTS.md, README or docs.
- History scan done and reported; repo pushed only after the owner confirms.
