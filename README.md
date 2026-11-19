# Token-Optimizer: codegraph skill

AI coding agents spend a large share of their tokens just *finding* code: globbing directories, grepping, and reading whole files to learn what each one does. **codegraph** builds that knowledge once, as a graph, and makes it the agent's first input. After that the agent reads only the exact line ranges it needs.

One build produces two views of the same graph:

- **For the agent:** `.codegraph/MAP.md`, a compact, token-budgeted index. It lists every file with its purpose and `uses:` / `used by:` / `tests:` edges, and every function/class/method with its signature and exact `START-END` lines. A query CLI (`find`, `sym`, `file`, `rdeps`, `deps`) answers precise questions such as "who calls this?" or "what breaks if I change this file?" without scanning the repo.
- **For you:** `.codegraph/graph.html`, an interactive, offline force-directed graph of the codebase. You can search files and symbols, colour by folder or language, switch between a file view and a folder view, focus on a node's neighbourhood, see callers and callees, and jump into VS Code at the exact line.

## Install (once)

```powershell
.\install.ps1          # Windows → ~/.claude/skills/codegraph
```
```sh
./install.sh           # macOS/Linux
```
Add `-Copilot` / `--copilot` to also install into `~/.copilot/skills`. Requires Node.js 16+ and has no npm dependencies.

## Use (per project)

In Claude Code, open any project and run:

```
/codegraph
```

That:
1. Builds `.codegraph/` (MAP.md, graph.json, graph.html, and a copy of the query CLI). The folder git-ignores itself.
2. Adds a short, marked block to the project's `CLAUDE.md` (and `AGENTS.md` / `.github/copilot-instructions.md` if present). From then on, **every new prompt** reads the map first and queries the graph instead of crawling the repo.

The graph keeps itself fresh. Any query notices changed, added or removed files and rebuilds (usually well under a second). To rebuild by hand:

```
node .codegraph/codegraph.js build
```

### Query examples

```
$ node .codegraph/codegraph.js find charge invoice
api/app/main.py:7-9  fn [POST /invoices/{id}/charge] charge_invoice(id: str)
api/app/services/billing.py:12-14  m charge(invoice: Invoice) -> bool
api/app/services/billing.py:17-19  fn compute_total(invoice) - Return invoice total including tax.  [3 refs]

$ node .codegraph/codegraph.js sym compute_total
* fn compute_total  api/app/services/billing.py:17-19
  referenced from (3):
    api/app/main.py:9 in charge_invoice (7-9)
    api/app/services/billing.py:13 in charge (12-14)
    api/tests/test_billing.py:4 in test_total (3-4)

$ node .codegraph/codegraph.js rdeps src/lib/db.ts
src/lib/db.ts is used by (depth 2):
  src/routes/auth.ts
    src/index.ts
```

### Options

| Flag | Effect |
|---|---|
| `--root <dir>` | Project to index (default: current directory) |
| `--budget <tokens>` | Size target for MAP.md (default 20000). Detail drops step by step, from full signatures and docs down to file-level only, and very large repos split into `map/*.md` area files. |
| `--no-html` | Skip the HTML viewer |
| `--no-instructions` | Don't touch CLAUDE.md / AGENTS.md |

Put a `.codegraphignore` (gitignore syntax) in the project to exclude more paths.

## How it works

`scripts/codegraph.js` is one dependency-free Node script:

1. **Walk:** respects `.gitignore`, skips dependency/build folders, generated files and files over 1MB, and tags tests, docs, config and vendored third-party code.
2. **Mask:** blanks comments and string bodies so brace matching and identifier scanning aren't fooled.
3. **Extract symbols** with per-language patterns. End lines come from brace matching (C-family), indentation (Python) or `end` keywords (Ruby/Lua). It also captures signatures, the first doc-comment sentence, the containing class, and HTTP routes.
4. **Resolve imports** to repo files: tsconfig path aliases, Python packages and relative imports, Go modules, Java packages, C# namespaces, Rust `mod`/`use crate::`, C includes, and Ruby/PHP/Lua/Dart conventions.
5. **Reference graph:** identifiers in each file are matched against the symbols it can see (same file plus imported files plus same package). That gives "called from `file:line` in `function`" edges.
6. **Render:** MAP.md at the most detailed level that fits the budget, graph.json, and graph.html (the viewer template with the data embedded).

The parsing is heuristic and fast rather than compiler-exact. Treat call edges as strong hints and confirm in source before relying on "no references".

## Layout

```
.claude/skills/codegraph/
  SKILL.md               skill definition (/codegraph)
  scripts/codegraph.js   builder + query CLI
  scripts/viewer.html    HTML viewer template
install.ps1 / install.sh copy the skill to ~/.claude/skills
```
