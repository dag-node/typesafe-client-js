#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Ondřej Nedomlel <tools@dagnode.com>
# SPDX-License-Identifier: MIT
# build.sh -- install what the lockfile pins, type-check, and emit dist/.
#
# The same build as `npm run build`, which is what CI runs. This script resolves the compiler rather than assuming
# one -- node_modules first, then a `tsc` on PATH, and either only at the version package.json pins -- so the
# artifact is the pinned compiler's output wherever it is built. TypeScript 7 ships `tsc.js` as a shim that execs
# a native binary out of node_modules, which an environment that refuses to exec from a project tree (a confined
# build account, a noexec mount) declines to run; there the compiler on PATH is the one that works.
#
# A version mismatch is a refusal rather than a fallback: the release checksum means something only if the same
# source builds to the same bytes, and two compiler versions do not.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

pinned="$(node --print 'require("./package.json").devDependencies.typescript')"

if [[ ! -d node_modules ]]; then
    printf 'installing from package-lock.json\n'
    npm ci --ignore-scripts --no-audit --no-fund
fi

# `tsc --version` prints "Version <x.y.z>"; a candidate that cannot run here prints nothing, and is reported and
# passed over instead of failing the build half-way through.
compiler_version() {
    "$1" --version 2>/dev/null | awk '{ print $NF }'
}

tsc=""
for candidate in ./node_modules/.bin/tsc "$(command -v tsc || true)"; do
    [[ -n "${candidate}" && -x "${candidate}" ]] || continue
    # Assigned through `if`, which `set -e` exempts: a candidate that aborts rather than exits (the native shim,
    # where exec from a project tree is refused) would otherwise end this script with its own signal status.
    if ! version="$(compiler_version "${candidate}")"; then
        version=""
    fi
    if [[ "${version}" == "${pinned}" ]]; then
        tsc="${candidate}"
        break
    fi
    if [[ -n "${version}" ]]; then
        printf 'skipping %s: TypeScript %s, this project pins %s\n' "${candidate}" "${version}" "${pinned}" >&2
    else
        printf 'skipping %s: it does not run here\n' "${candidate}" >&2
    fi
done

if [[ -z "${tsc}" ]]; then
    printf 'no TypeScript %s available. Install it with: npm ci --ignore-scripts\n' "${pinned}" >&2
    exit 1
fi

printf 'building with %s (TypeScript %s)\n' "${tsc}" "${pinned}"
"${tsc}" --project tsconfig.json --noEmit
"${tsc}" --project tsconfig.json
printf 'dist/ built. Run the suite with: npm test\n'
