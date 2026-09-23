# Changelog

Minimal, unofficial TypeScript client for the TypeSafe System One API,
compiled to plain ESM with no runtime dependency. Not affiliated with
TypeSafe, and not its official SDK. MIT licensed.

Source, issues and releases:
https://github.com/dag-node/typesafe-client-js

Newest first.

## 0.1.0 — 2026-09-23

First release. There is no earlier version to upgrade from; this entry
states what the release contains.

### Added

- The `decide` command. It reads a line-oriented listing on stdin, asks the
  TypeSafe System One API one bounded question per line, and prints the
  lines bearing on a stated task in full; the rest are listed by id on one
  summary line. The exit status names the failure class — `2` input, `3`
  configuration, `4` provider, `5` contract, `6` deadline — and on every
  non-zero status one stderr line is all that is printed. A reader that
  closes stdout early, as `| head -1` does, ends the command with status 0
  and nothing on stderr.
- Three readers for stdin, chosen by `--format`: `lines`, `prose-check`,
  and `msbuild`, which reduces a build log to its diagnostics and reports
  how many lines it set aside.
- One `KEY=value` file, named by `--config`, carrying the API key, the
  endpoint, the model, and the values tuned per host: the keep threshold,
  the uncertain band and the per-attempt timeout. Each value is held to the
  form its key documents; a value outside that form is refused rather than
  replaced with a default. `typesafe.conf.example` carries every key at its
  default.
- `--threshold`, overriding the file's keep threshold for one call.
- `--usage-log <file>`, appending one JSON line of counts per run — items,
  kept, requests, tokens, elapsed time, outcome, the client and template
  versions — with no item text, no task and no key in it. Without the flag
  the command writes no file.
- `--version`, or `-v`, printing the release a copy came from.
- A library entry with declarations beside it, for a program that embeds
  the client rather than running the command.
- Signed release artifacts: each tagged release carries the build as a
  tarball with its `sha256` and a detached signature from the dag-node key,
  named apart from the source archives GitHub attaches. The key is
  published at https://rpm.dagnode.com/RPM-GPG-KEY-dag-node, and
  `README.md` carries its fingerprint and the verification commands.
- `SECURITY.md`, stating which findings belong to this project and which
  belong to TypeSafe.

### Security

- The key reaches the process through the configuration file alone. The
  command reads no environment variable and takes no key as an argument,
  only the path to the file. That file is opened without following a
  symlink, checked and read through one descriptor, so the file checked is
  the file read; one other users can read or write is refused.
- A response is untrusted input. The status, the content type and a byte
  cap run before `JSON.parse`; the projection after it rebuilds the
  documented shape on a null-prototype object, walking the ids the request
  asked for and dropping rather than coercing. A redirect away from the
  configured origin is refused, so neither the key nor the listing reaches
  the host it names.
- A listing is untrusted input. Stdin is refused as it passes the input
  bound rather than buffered whole, every parser pattern runs in time
  linear in the line, and the stderr line is rendered with control
  characters replaced, so text quoted back in it cannot add a line or style
  a terminal. An item carrying a Unicode tag character is refused: those
  reach the model as text while staying invisible to a reader. Zero-width
  characters and bidirectional controls are counted on the summary line and
  sent unchanged, so a caller asking which lines carry one still gets the
  answer; right-to-left text and the marks U+200E and U+200F are not
  counted.
