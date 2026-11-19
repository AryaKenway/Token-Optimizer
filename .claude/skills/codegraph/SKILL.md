---
name: codegraph
description: Build (or refresh) a code graph of the current project so agents stop burning tokens hunting for code. Produces an agent-facing index (.codegraph/MAP.md, with every file's purpose, dependencies, dependents and every function/class with exact line ranges), a query CLI for symbol/caller/impact lookups, and an interactive HTML graph (.codegraph/graph.html) for humans. Use when the user asks to map, index, graph or visualize the codebase, run /codegraph, or set up token-efficient navigation for a repo.
argument-hint: "[project path] [--budget N] [--no-instructions]"
---

# codegraph

Turns a repository into a navigable graph so later prompts jump straight to the right file and line range instead of globbing, grepping and reading whole files.

Outputs (all in `<project>/.codegraph/`, which ignores itself in git):

| File | For | What it is |
|---|---|---|
| `MAP.md` | agents | Compact index: overview, directory tree, then per file: purpose, `uses:` / `used by:` / `tests:`, and every symbol as `kind signature START-END`. It shrinks its own detail to fit a token budget (default 20k), and splits into `map/*.md` area files for very large repos. |
| `codegraph.js` | agents | Query CLI (a copy of this skill's script, so any agent can run it). It rebuilds itself when files have changed. |
| `graph.json` | tools | Full graph data: files, symbols, file edges, symbol references. |
| `graph.html` | humans | Self-contained interactive graph (works offline). It has search, folder/language colouring, focus mode, and a symbol panel with callers and "open in VS Code" links. |

## Steps

1. **Pick the project root.** Use the path the user gave, otherwise the current working directory (prefer the git root if you're in a subfolder).
2. **Build.** The script sits next to this file at `scripts/codegraph.js`, so use this skill's base directory:
   ```
   node "<skill-base-dir>/scripts/codegraph.js" build --root "<project-root>"
   ```
   Options: `--budget <tokens>` sets MAP.md's size target, `--no-html` skips the viewer, and `--no-instructions` skips step 3. Requires Node 16+ and has no dependencies.
3. **Hook future prompts.** The build adds (or refreshes) a block between `<!-- codegraph:start -->` and `<!-- codegraph:end -->` in the project's `CLAUDE.md`. It does the same in `AGENTS.md` and `.github/copilot-instructions.md` if those exist. That block tells every later session to read `.codegraph/MAP.md` first and use the query CLI. Tell the user which files were touched. Nothing outside the block is changed.
4. **Report briefly.** Give the counts, MAP.md's size in tokens, and the path to `graph.html`, which the user can open in a browser (on Windows, `start .codegraph\graph.html`). Mention any warnings, such as skipped large or generated files.
5. If the user also asked a code question, answer it now using the navigation protocol below.

## Navigation protocol (how to use the graph)

1. Read `.codegraph/MAP.md` once at the start of a code task. In split mode, also read only the area file(s) relevant to the task.
2. Choose files and symbols from the map, then read **only** their line ranges: `Read(file, offset=START, limit=END-START+1)`. Widen a little if you need surrounding context.
3. Use the CLI instead of Grep/Glob sweeps (run it from the project root):
   - `node .codegraph/codegraph.js find <words>` gives ranked symbols and files with `path:START-END`.
   - `node .codegraph/codegraph.js sym <name>` gives the definition, every reference site (`file:line in function`), and what it calls. Use it before changing a function's signature.
   - `node .codegraph/codegraph.js rdeps <path> [--depth N]` lists the files that depend on this one, i.e. what to re-check or test after a change.
   - `node .codegraph/codegraph.js file <path>` gives all symbols, imports and dependents of one file.
   - `node .codegraph/codegraph.js deps <path>` and `stale` are also available.
4. The graph is an index, not the source of truth. Line numbers come from the last build, and the CLI refreshes automatically. After you edit files, MAP.md can be slightly stale until the next query or build. Fall back to Grep only for things the graph doesn't model (string literals, config values, comments).

## Notes

- Languages: JS/TS (incl. JSX/TSX, Vue/Svelte scripts, tsconfig path aliases), Python, Go (go.mod), Java, Kotlin, Scala, C#, C/C++, Rust (mod/use), Ruby, PHP, Swift, Dart, Lua, shell and SQL. It also indexes Markdown headings, package.json scripts and Makefile targets. HTTP routes are detected for Express-style calls, Flask/FastAPI/Nest decorators, Spring `@*Mapping` and ASP.NET `[Http*]`.
- It respects `.gitignore` and `.git/info/exclude`, plus an optional `.codegraphignore` (gitignore syntax) for anything else to drop. Dependency and build folders, generated files, and files over 1MB are skipped. Third-party code vendored into the repo (e.g. Unity `Assets/Plugins`, `third_party/`) stays queryable but is only summarized in MAP.md.
- Parsing is fast and heuristic (no compilers involved), so call edges are name-based approximations. Verify before relying on "no references found".
