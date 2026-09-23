# typesafe-client-js

[![CI](https://github.com/dag-node/typesafe-client-js/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dag-node/typesafe-client-js/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Node](https://img.shields.io/badge/node-%3E%3D22-brightgreen)
![Runtime dependencies: none](https://img.shields.io/badge/runtime%20dependencies-none-brightgreen)

Minimal, unofficial TypeScript client for the TypeSafe System One API,
compiled to plain ESM with no runtime dependency and no bundler.

This project is not affiliated with [TypeSafe](https://typesafe.ai/) and is not the official [SDK](https://github.com/typesafe-ai/typesafe-sdk-js).
It implements the subset of the API one caller needs — a `noul` question per
item, asked in bounded chunks — and type-checks that subset against the
official SDK's published declarations.

## Quick start

```bash
npm ci --ignore-scripts && npm run build && bash tests/unit.sh
```

The build type-checks `src/` under a strict `nodenext` configuration and
emits `dist/`: one `.mjs` per module with its `.d.mts` beside it, exactly as
written, with no bundler and no minifier in the build at all. `tsc` is the
only tool, so anyone can reproduce the output and compare it to the source.
Node 22 or newer runs `dist/decide.mjs` directly. `bash build.sh` produces
the same output and is the path to take where the compiler in
`node_modules` cannot be executed: it picks whichever compiler runs at the
version `package.json` pins, and refuses any other version.

`bash tests/unit.sh` (also `npm test`) runs the offline suite: every
refusal the command makes before a request, each stdin parser, the answer
contract, each gate on a hostile response, the pinning of the file's
endpoint, key and model over an environment variable of the same name, and
the command end to end against a stub that stands in for the provider —
with no environment at all, with a read-only file in a read-only directory,
and with nothing written unless `--usage-log` names a file. No case opens
a connection.
It runs against `dist/`, so it follows the build rather than preceding it,
and CI fails on it.

```bash
grep -rn parse_config src | node dist/decide.mjs filter --task "which lines define the config parser"
```

The command reads a line-oriented listing on `stdin`, asks the API one bounded
question per line, and prints the lines that bear on the task in full; the
rest are listed by id on one summary line, so a caller sees what was dropped.
`--format` selects how stdin is read — `lines`, `prose-check`, or `msbuild`,
which reduces a build log to its diagnostics. `--threshold` moves the
probability at which an item is kept.

Exit status tells a caller what to fall back to. The class column is the
token the stderr line carries, as `decide: <class>: <message>`:

| status | class | what happened |
|---|---|---|
| `0` | — | a result was printed |
| `2` | `input` | the arguments, or a listing that is empty or past a bound |
| `3` | `configuration` | no credential file, or one the checks refuse |
| `4` | `provider` | the provider refused the request or was unreachable |
| `5` | `contract` | the answer did not hold the documented shape |
| `6` | `deadline` | the deadline passed |
| `1` | — | an unexpected error |

On every non-zero status the single stderr line is all that is printed, so
the caller falls back to the listing it already holds.

`--usage-log <file>` appends one JSON line of counts per run — items, kept,
requests, tokens, elapsed time, the outcome — with no item text, no task and
no key in it. Without the flag the command writes no file at all, and a path
it cannot open costs the line, not the result.

## Configuration

The credential comes from the `KEY=value` file `--config` names. That file
supplies the API key, the base URL, the host that URL must resolve to, and
the model; the client refuses a symlink, a file other users can read or
write, a placeholder key, a base URL that is not HTTPS, and a host the file
does not also name. Two modes satisfy that check: `0600` when you own the
file and run the command yourself, and `0640 root:<group>` when a service
account reads it. The file is opened without following a symlink and every
check runs on the open descriptor, so the file checked is the file read.
The key is read at call time and travels from that file to the request's
`Authorization` header; the client does not write it to `process.env`, and
does not read one from there either. A redirect from the origin is not
followed: it is refused as the provider's answer, so neither the key nor the
listing reaches the host it names.

`src/defaults.mts` holds the fallback for each of those keys and no other
code, and `config.mts` imports them from there, so the values an operator
may change are one file rather than a search. The request bounds are
deliberately not among them: the chunk size, the item cut and the state
budget are chosen against each other, and they stay in `core.mts` with the
code that reads them.

## How a call runs

```text
  listing on stdin
        |
        v
  parse        one item per line; ids checked, text cut to the item bound
        |
        v
  chunk        bounded by item count and state size, both set in core.mts
        |
        v
  request      POST <base>/v1/systemone, bearer from --config, one retry
        |
        v
  gate         status -> content type -> byte cap -> JSON.parse -> projection
        |
        v
  contract     every answer the request asked for, present and in range
        |
        v
  stdout       the kept lines in full; the rest as ids on the summary line
```

A failure at any step exits with that step's class and prints one line, so
the caller is never left holding a partial result.

| module | what it owns |
|---|---|
| `defaults.mts` | the fallback for each configuration key, and no other code |
| `config.mts` | the file's form, and every refusal on it |
| `help.mts` | the usage text |
| `errors.mts` | the failure classes and the exit status of each |
| `templates.mts` | the question, and the criteria it is judged against |
| `parsers.mts` | a listing to items, one reader per `--format` |
| `transport.mts` | the one request, and the gate on the response |
| `core.mts` | the bounds, the chunking, the request loop, the contract check |
| `decide.mts` | the command |
| `index.mts` | the library surface |

## Scope

`@typesafe-ai/sdk` is a devDependency, pinned for its declarations alone.
The request body, the question builders and each answer field bind to those
declarations through `import type`, so a release that renames or retypes one
of them fails the next build here. `import type` is erased on emit: the
emitted file does not import the SDK, and a consumer does not install it.

Every response is sanitized as untrusted input, in the order [How a call
runs](#how-a-call-runs) shows, so a body that is not a small JSON result
does not reach `JSON.parse`. The projection rebuilds the documented shape on a
null-prototype object, reading own properties only and walking the ids the
caller asked for, and it drops rather than coerces, so the contract check
still reports what it could not fill.

The listing is untrusted too: stdin is refused the moment it passes the
input bound rather than buffered whole, every parser pattern runs in time
linear in the line, a `path:line` id is taken only where it is well-formed
and not yet taken (a second finding on the same line keeps its line as
`L<n>`), and the one stderr line is rendered with every control character
from an input or a body replaced, so text quoted in it cannot add a line or
style a terminal.

Two classes of invisible character part ways there. An item carrying a
Unicode tag character is refused: those are invisible to a reader and
ordinary text to a tokenizer, so sending one puts instructions in the
request that its caller cannot see. Zero-width characters and bidirectional
controls are counted on the summary line and sent unchanged — they mislead
a reader rather than the model, and a caller asking which lines carry a
bidirectional override needs them to arrive intact. The count targets the
controls, not right-to-left text: a line of Arabic or Hebrew is not
counted, and neither are the marks U+200E and U+200F, which are ordinary
formatting wherever a script mixes with digits.

## Using the build output

Each tagged release carries `dist/` as a tarball with its `sha256` and a
detached signature. A consumer vendors that at a pinned tag: the output is
small enough to read, so the code that runs is the code that was reviewed,
and `npm run build` reproduces it from the tag for anyone checking. The
project does not publish to a package registry yet.

```bash
curl -fsSO https://rpm.dagnode.com/RPM-GPG-KEY-dag-node
gpg --import RPM-GPG-KEY-dag-node
sha256sum -c typesafe-client-js-dist-v0.1.0.tar.gz.sha256
gpg --verify typesafe-client-js-dist-v0.1.0.tar.gz.asc typesafe-client-js-dist-v0.1.0.tar.gz
```

The key is published on `dagnode.com` rather than attached to the release,
so it does not travel with what it signs. Check the imported key against
this fingerprint:

```text
67F4 2DC1 8BF7 64B4 2D82  F142 56D2 F802 CF98 32E4
```

`node dist/decide.mjs --version` prints the release a vendored copy came
from, for a host where the tarball and its tag are no longer at hand.

## Licence

MIT. See `LICENSE`.
