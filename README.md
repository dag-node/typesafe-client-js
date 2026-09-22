# typesafe-client-js

Minimal, unofficial TypeScript client for the TypeSafe System One API,
emitted as one readable, dependency-free ESM file.

This project is not affiliated with TypeSafe and is not the official SDK.
It implements the subset of the API one caller needs — a noul question per
item, asked in bounded chunks — and type-checks that subset against the
official SDK's published declarations.

## Quick start

```bash
npm ci --ignore-scripts && npm run build
```

The build type-checks `src/` under a strict `nodenext` configuration and
emits `dist/decide.mjs`: one file, no runtime dependencies, no minification.
Node 22 or newer runs it directly.

```bash
grep -rn parse_config src | node dist/decide.mjs filter --task "which lines define the config parser"
```

The command reads a line-oriented listing on stdin, asks the API one bounded
question per line, and prints the lines that bear on the task in full; the
rest are listed by id on one summary line, so a caller sees what was dropped.
`--format` selects how stdin is read — `lines`, `prose-check`, or `msbuild`,
which reduces a build log to its diagnostics. `--threshold` moves the
probability at which an item is kept.

Exit status tells a caller what to fall back to:

- `0` a result was printed
- `2` input: the arguments, or a listing that is empty or past a bound
- `3` configuration: no credential file, or one the checks refuse
- `4` the provider refused the request or was unreachable
- `5` the answer did not hold the documented shape
- `6` the deadline passed
- `1` an unexpected error

On every non-zero status the single stderr line is all that is printed, so
the caller falls back to the listing it already holds.

## Configuration

The credential comes from the `KEY=value` file `--config` names. That file
supplies the API key, the base URL, the host that URL must resolve to, and
the model; the client refuses a symlink, a file other users can read or
write, a placeholder key, a base URL that is not HTTPS, and a host the file
does not also name. The key is read at call time and travels from that file
to the request's `Authorization` header; the client does not write it to
`process.env`, and does not read one from there either.

Everything else is a constant in the block at the top of `dist/decide.mjs` —
the chunk and payload bounds, the timeouts, the keep threshold, and the
question text. The emitted file is unminified and keeps its doc comments, so
an operator edits that block in place. Those values come from the file
itself, not from a second file or an environment variable.

## Scope

`@typesafe-ai/sdk` is a devDependency, pinned for its declarations alone.
The request body, the question builders and each answer field bind to those
declarations through `import type`, so a release that renames or retypes one
of them fails the next build here. `import type` is erased on emit: the
emitted file does not import the SDK, and a consumer does not install it.

Every response is untrusted input, gated in a fixed order — status, then
content type, then a byte cap on the read — so a body that is not a small
JSON result does not reach `JSON.parse`. The projection after it rebuilds
the documented shape on a null-prototype object, reading own properties only
and walking the ids the caller asked for, and it drops rather than coerces,
so the contract check still reports what it could not fill.

## Using the build output

`dist/decide.mjs` is attached to each tagged release with its `sha256`. A
consumer vendors that file at a pinned tag and verifies the checksum: the
file is small enough to read, so the code that runs is the code that was
reviewed. The project does not publish to a package registry.

## Licence

MIT. See `LICENSE`.
