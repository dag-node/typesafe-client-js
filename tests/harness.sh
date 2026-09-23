#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Ondřej Nedomlel <tools@dagnode.com>
# SPDX-License-Identifier: MIT
# tests/harness.sh
# The counters and verdict verbs a suite here reports through, so a run's output is greppable line by line and its
# exit status is the whole result: 0 when no check failed, 1 otherwise. A suite sources this file; it defines
# functions and does not run a check of its own.
#
# A skipped check prints its own verdict and its reason. It is not counted as a pass, so a suite that could not run
# a case says which one rather than reporting a shorter green run.

_PASSED=0
_FAILED=0
_SKIPPED=0

_rule() { printf '%*s' "$1" "" | tr ' ' '-'; }

section() { printf '\n  %s\n  %s\n' "$1" "$(_rule 60)"; }
pass() { _PASSED=$((_PASSED + 1)); printf '  PASS  %s\n' "$1"; }
fail() { _FAILED=$((_FAILED + 1)); printf '  FAIL  %s\n' "$1"; }
skip() { _SKIPPED=$((_SKIPPED + 1)); printf '  SKIP  %s -- %s\n' "$1" "${2:-no reason given}"; }

# mktestdir: a private directory in TESTDIR, removed when the shell exits however it exits.
mktestdir() {
    TESTDIR="$(mktemp -d)"
    # shellcheck disable=SC2064  # Expanded now on purpose: the trap has to name this run's directory.
    trap "rm -rf '${TESTDIR}'" EXIT
}

# finish: print the totals and answer with the run's verdict, which becomes the suite's exit status.
finish() {
    printf '\n  %s\n  %d passed, %d failed, %d skipped\n\n' "$(_rule 42)" "${_PASSED}" "${_FAILED}" "${_SKIPPED}"
    (( _FAILED == 0 ))
}
