// SPDX-License-Identifier: MIT
// src/help.mts
// The command's help text, kept apart from the command so the words an operator reads are edited without touching
// argument parsing. It is printed for `--help` and appended to the refusals a reader can act on -- a missing
// template, an unknown one, an absent `--config` -- so the correction is on screen beside the complaint.
//
// The option list and the exit statuses here restate what decide.mts implements; a flag added there is added here.

export const USAGE = `usage: <listing> | node decide.mjs filter --task "<one sentence>" --config <file> [--format lines|prose-check|msbuild] [--threshold 0.5] [--usage-log <file>]
  filter       keep the lines that bear on the task; the rest are listed by id on the summary line
  --config     the KEY=value file holding the API key, the endpoint and the tuned values. Required
  --format     lines (default), prose-check, or msbuild (a build log's diagnostics; the rest set aside)
  --threshold  the least P(true) that keeps an item, overriding the file's
  --usage-log  a file to append one JSON line of counts to; without it nothing is written
  triage       deferred -- not dispatched in this release
exit: 0 result, 2 input, 3 configuration, 4 provider, 5 contract, 6 deadline, 1 unexpected`;
