// SPDX-License-Identifier: MIT
// src/index.mts
// The library surface, for a program that embeds the client rather than running the command. It re-exports what a
// caller needs to ask the question itself: read a configuration (or build one), make a transport, turn a listing
// into items, and run the filter template over them.
//
// The command (decide.mts) is a consumer of this surface, not the surface itself: it adds argument parsing, the
// usage log and the exit-status mapping. An embedder supplying its own key does not need config.mts -- a
// TypeSafeConfig is a plain value, and makeClient takes it.

export { readConfig, parseKeyValue, type TypeSafeConfig } from "./config.mjs";
export {
    DEFAULT_BASE_URL,
    DEFAULT_ENDPOINT_HOST,
    DEFAULT_MODEL,
    DEFAULT_THRESHOLD,
    DEFAULT_TIMEOUT_MS,
    DEFAULT_UNCERTAIN_BAND,
} from "./defaults.mjs";
export {
    contractProblems,
    decideFilter,
    decideTriage,
    LIMITS,
    makeClient,
    type Decision,
    type NoulRow,
    type ChoiceRow,
    type RequestRecord,
} from "./core.mjs";
export { DecideError, ErrorCode, EXIT_STATUS } from "./errors.mjs";
export { FORMATS, parse, type Format } from "./parsers.mjs";
export {
    filter,
    triage,
    MAX_TASK_CHARS,
    TEMPLATE_VERSION,
    TRIAGE_OPTIONS,
    type FilterParams,
    type FilterTemplate,
    type Item,
    type NoulAnswer,
    type ChoiceAnswer,
    type TriageParams,
    type TriageTemplate,
} from "./templates.mjs";
