#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# tests/unit.sh
# The offline suite over the built command in dist/. What it proves without a network: every refusal the command
# makes before a request leaves the process with the exit status its header documents and one stderr line naming
# the class; the configuration file's refusals hold on the world bits, on a symlink, and on each value whose form
# config.mts states; the request carries the file's own origin, key and model, and an environment variable of the
# same name changes none of them; each stdin parser keeps a `path:line` id once, falls back to `L<n>` on a
# repeat, refuse a record they cannot place and read a hostile line in linear time; the answer contract rejects each
# malformed body it is driven with; and each gate refuses the response built to pass it. No case here opens a
# connection.
#
# Hermetic: fixtures in the suite's own temporary directory, removed on exit.
set -euo pipefail
# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/harness.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
section "typesafe-client: the decide command, offline (unit)"

DIR="${ROOT}/dist"
if [[ ! -r "${DIR}/decide.mjs" ]]; then
    skip "typesafe-client" "dist/decide.mjs is not built -- run: npm run build"; finish; exit
fi
if ! command -v node >/dev/null 2>&1; then
    skip "typesafe-client" "node is not on PATH"; finish; exit
fi
CLI="${DIR}/decide.mjs"

mktestdir
# run <stdin-text> <args...>: run the command with the given stdin; sets out, err, rc.
run() {
    local input="$1"; shift
    set +e
    out="$(printf '%s' "${input}" | node "${CLI}" "$@" 2>"${TESTDIR}/err")"
    rc=$?
    set -e
    err="$(cat "${TESTDIR}/err")"
}
expect_refusal() {
    local what="$1" want_rc="$2" class="$3"
    if [[ ${rc} -eq ${want_rc} && "${out}" == "" && "${err}" == "decide: ${class}: "* && "$(wc -l <<<"${err}")" -le 6 ]]; then
        pass "${what}: exit ${want_rc}, one '${class}' line on stderr, nothing on stdout"
    else
        fail "${what}: rc=${rc} stdout='$(head -c 80 <<<"${out}")' stderr='$(head -c 160 <<<"${err}" | tr '\n' '|')'"
    fi
}

# ── refusals before any request ───────────────────────────────────────────────────────────────────────────────
run "" --help
if [[ ${rc} -eq 0 && "${out}" == usage:* && "${out}" == *"exit: 0 result, 2 input, 3 configuration, 4 provider, 5 contract, 6 deadline, 1 unexpected"* ]]; then
    pass "--help prints the usage with the exit-status table and exits 0"
else
    fail "--help: rc=${rc} out='$(head -c 120 <<<"${out}")'"
fi

# `--version` answers on a host that has no configuration file, which is the state that raises the
# question of which build this is, so it is checked before every other argument.
for flag in --version -v; do
    run "" "${flag}"
    if [[ ${rc} -eq 0 && "${out}" == "typesafe-client-js "* && -z "${err}" ]]; then
        pass "${flag} prints the client version and exits 0"
    else
        fail "${flag}: rc=${rc} out='${out}' err='$(head -c 120 <<<"${err}")'"
    fi
done
# The version is written in two places, so the suite holds them to each other: a release
# cannot ship an artifact whose version disagrees with its own manifest.
pkg_version="$(node -p "require('${ROOT}/package.json').version")"
src_version="$(node -e "import('${DIR}/help.mjs').then((m) => process.stdout.write(m.VERSION))")"
if [[ "${pkg_version}" == "${src_version}" ]]; then
    pass "the version in help.mts matches package.json (${pkg_version})"
else
    fail "help.mts VERSION is ${src_version}, package.json is ${pkg_version}"
fi
run "x" ; expect_refusal "no template" 2 input
run "x" triage; expect_refusal "the deferred triage template" 2 input
run "x" nonsense; expect_refusal "an unknown template" 2 input
run "x" filter; expect_refusal "filter without --task" 2 input
run "x" filter --task t --format wat; expect_refusal "an unknown --format" 2 input
run "x" filter --task t --threshold 7; expect_refusal "a threshold outside 0..1" 2 input
run "x" filter --task t --bogus; expect_refusal "an unknown option" 2 input
run "x" filter --task "$(printf 'a%.0s' {1..401})"; expect_refusal "a --task over the bound" 2 input
run "x" filter --task t; expect_refusal "no --config" 3 configuration

# ── the credential file ───────────────────────────────────────────────────────────────────────────────────────
KEY="tsk_unit_0123456789abcdefghij"
conf="${TESTDIR}/typesafe.conf"
printf 'TYPESAFE_API_KEY=%s\n' "${KEY}" > "${conf}"; chmod 0644 "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "a world-readable file" 3 configuration
chmod 0602 "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "a world-writable file" 3 configuration
chmod 0660 "${conf}"
ln -s "${conf}" "${TESTDIR}/link.conf"
run "x" filter --task t --config "${TESTDIR}/link.conf"; expect_refusal "a symlink" 3 configuration
run "x" filter --task t --config "${TESTDIR}/absent.conf"; expect_refusal "a missing file" 3 configuration
printf 'TYPESAFE_API_KEY=replace-with-your-key\n' > "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "the template placeholder" 3 configuration
printf 'TYPESAFE_API_KEY=%s\nTYPESAFE_BASE_URL=https://jev-ai.pro\n' "${KEY}" > "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "another host not named in TYPESAFE_ENDPOINT_HOST" 3 configuration
printf 'TYPESAFE_API_KEY=%s\nTYPESAFE_BASE_URL=http://api.typesafe.ai\n' "${KEY}" > "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "a non-https base URL" 3 configuration

# Each value the file carries is held to the form its key documents, and a value outside it is a refusal rather
# than a fallback to the default: a run that quietly used another threshold would change what is kept, silently.
write_conf() { printf 'TYPESAFE_API_KEY=%s\n%s\n' "${KEY}" "$1" > "${conf}"; chmod 0600 "${conf}"; }
printf 'TYPESAFE_API_KEY=short\n' > "${conf}"; chmod 0600 "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "a key under the length bound" 3 configuration
write_conf 'TYPESAFE_THRESHOLD=high'
run "x" filter --task t --config "${conf}"; expect_refusal "a threshold that is not a number" 3 configuration
write_conf 'TYPESAFE_THRESHOLD=1.5'
run "x" filter --task t --config "${conf}"; expect_refusal "a threshold outside 0 to 1" 3 configuration
write_conf 'TYPESAFE_UNCERTAIN_BAND=0.7,0.3'
run "x" filter --task t --config "${conf}"; expect_refusal "an uncertain band whose low exceeds its high" 3 configuration
write_conf 'TYPESAFE_UNCERTAIN_BAND=0.35'
run "x" filter --task t --config "${conf}"; expect_refusal "an uncertain band that is one value" 3 configuration
write_conf 'TYPESAFE_TIMEOUT_MS=0'
run "x" filter --task t --config "${conf}"; expect_refusal "a timeout under the supported range" 3 configuration
write_conf 'TYPESAFE_TIMEOUT_MS=1.5'
run "x" filter --task t --config "${conf}"; expect_refusal "a timeout that is not whole milliseconds" 3 configuration
write_conf 'TYPESAFE_ENDPOINT_HOST=not a host'
run "x" filter --task t --config "${conf}"; expect_refusal "an endpoint host that is not a hostname" 3 configuration
write_conf 'TYPESAFE_MODEL=jev 1.13.0'
run "x" filter --task t --config "${conf}"; expect_refusal "a model id carrying a space" 3 configuration
{ printf 'TYPESAFE_API_KEY=%s\n' "${KEY}"; head -c 70000 /dev/zero | tr '\0' '#'; printf '\n'; } > "${conf}"; chmod 0600 "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "a file over the size bound" 3 configuration
write_conf "TYPESAFE_BASE_URL=https://user:hunter2@api.typesafe.ai"
run "x" filter --task t --config "${conf}"; expect_refusal "a base URL carrying a userinfo" 3 configuration
if ! grep -qF "hunter2" "${TESTDIR}/err"; then pass "the userinfo refusal leaves the password out"; else fail "the userinfo refusal shows the password"; fi
mkfifo "${TESTDIR}/fifo.conf"; chmod 0600 "${TESTDIR}/fifo.conf"
run "x" filter --task t --config "${TESTDIR}/fifo.conf"; expect_refusal "a FIFO, refused without blocking on the open" 3 configuration
# A byte-order mark, a quoted key and a trailing comment are all read past: the refusal that follows is the next
# key's, so the key itself was accepted.
printf '\xef\xbb\xbfTYPESAFE_API_KEY="%s" # issued 2026-09\nTYPESAFE_THRESHOLD=2\n' "${KEY}" > "${conf}"; chmod 0600 "${conf}"
run "x" filter --task t --config "${conf}"; expect_refusal "a BOM, a quoted key with a comment after it, then a bad threshold" 3 configuration
if [[ "${err}" == *"TYPESAFE_THRESHOLD"* ]]; then pass "the quoted key was accepted: the refusal names the threshold"; else fail "the refusal is not the threshold's: ${err}"; fi
# A valid file: the next refusal is the listing's, so the file was accepted (group-writable by ACL mask is fine).
printf 'TYPESAFE_API_KEY=%s\n' "${KEY}" > "${conf}"; chmod 0660 "${conf}"
run "" filter --task t --config "${conf}"; expect_refusal "a valid file, then an empty listing" 2 input
run "$(printf 'x:%d: y\n' {1..1001})" filter --task t --config "${conf}"; expect_refusal "a listing over the item bound" 2 input
run "$(head -c 4000001 /dev/zero | tr '\0' x)" filter --task t --config "${conf}"; expect_refusal "stdin over the input bound, refused as it is read" 2 input
run "$(printf 'a:1: y\nb:2: z\nnot a finding\n')" filter --task t --format prose-check --config "${conf}"; expect_refusal "a prose-check record the parser cannot place" 2 input
run "$(printf 'a:1: safe\U000E0001hidden\n')" filter --task t --config "${conf}"; expect_refusal "a Unicode tag character in an item" 2 input
# The refused line is quoted on stderr; the escape and the carriage return it carries are not.
run "$(printf 'bad \033[31mred\033[0m\r%s\n' "$(printf 'a%.0s' {1..400})")" filter --task t --format prose-check --config "${conf}"; expect_refusal "a refused line carrying an escape sequence" 2 input
if [[ "$(wc -l <<<"${err}")" -eq 1 ]] && ! grep -q $'\033' "${TESTDIR}/err" && ! grep -q $'\r' "${TESTDIR}/err"; then pass "the stderr line holds no control character from the input"; else fail "stderr carries a control character: $(cat -A "${TESTDIR}/err" | head -c 200)"; fi
if ! grep -qF "${KEY}" "${TESTDIR}/err"; then pass "no refusal line carries the key"; else fail "a refusal line carries the key"; fi

# ── the library, driven directly ──────────────────────────────────────────────────────────────────────────────
# The parsers, the contract and the request's pinning are asserted from node, where the fetch the transport makes is
# injected and records what it was handed. Every case prints one line: `ok <what>` or `FAIL <what>: <why>`.
cat > "${TESTDIR}/drive.mjs" <<EOF
import { parseLines, parseProseCheck, parseMsbuild, parse } from "${DIR}/parsers.mjs";
import { contractProblems, makeClient, decideFilter, LIMITS, chunkItems, normalizeItems, isItemId } from "${DIR}/core.mjs";
import { filter } from "${DIR}/templates.mjs";
import { readConfig } from "${DIR}/config.mjs";
const report = (cond, what, why = "") => console.log(cond ? \`ok \${what}\` : \`FAIL \${what}: \${why}\`);
const lines = parseLines("src/a.sh:12: foo()\\n\\nplain line\\nsrc/b.sh:3:bar\\n").items;
report(lines.length === 3 && lines[0].id === "src/a.sh:12" && lines[1].id === "L2" && lines[2].id === "src/b.sh:3" && lines[0].text === "src/a.sh:12: foo()", "lines: path:line ids, L<n> fallback, blank lines skipped", JSON.stringify(lines));
const pc = parseProseCheck("docs/x.md:5: unbacked-absolute [never] -- name the guard\\n    The account is never an admin.\\n\\n1 finding(s). See the skill\\n").items;
report(pc.length === 1 && pc[0].id === "docs/x.md:5" && pc[0].rule.startsWith("unbacked-absolute") && pc[0].text === "The account is never an admin.", "prose-check: id, rule and excerpt split, trailer skipped", JSON.stringify(pc));
const many = normalizeItems(Array.from({ length: 95 }, (_, i) => ({ id: \`i\${i}\`, text: "t" }))).items;
const per = LIMITS.maxItemsPerRequest;
const want = [];
for (let left = 95; left > 0; left -= per) want.push(Math.min(per, left));
report(chunkItems(many).map((c) => c.length).join("/") === want.join("/"), \`chunking 95 items as \${want.join("/")}\`, JSON.stringify(chunkItems(many).map((c) => c.length)));
// A line whose text carries a clock time matches the path:line: shape and is not a valid id: it falls back to
// L<n> rather than failing the listing, which is what every MSBuild log at normal verbosity depends on.
const clock = parseLines("Build started 9/22/2026 10:18:09 AM.\\nsrc/a.sh:12: real\\nTime Elapsed 00:00:01.81\\n").items;
report(clock.length === 3 && clock[0].id === "L1" && clock[1].id === "src/a.sh:12" && clock[2].id === "L3", "lines: a clock time falls back to L<n>", JSON.stringify(clock));
// Two findings on one line, as a gcc-format checker prints them, derive one path:line: the second keeps its line under L<n>.
const twice = parseLines("a.sh:3:5: warning SC2086\\na.sh:3:9: note SC2046\\n").items;
report(twice.length === 2 && twice[0].id === "a.sh:3" && twice[1].id === "L2", "lines: a repeated path:line falls back to L<n>", JSON.stringify(twice));
// A location spelled like the fallback ("L9 : error") is not taken as an id, so no fallback can collide with one.
const lShaped = parseMsbuild("real.cs(1,2): error CS1: m\\nL9 : error CS2: n\\n").items;
report(lShaped.length === 2 && lShaped[0].id === "real.cs:1" && lShaped[1].id === "L2", "msbuild: an L<n>-shaped location falls back to its own ordinal", JSON.stringify(lShaped));
const pcTwice = parseProseCheck("d.md:5: rule-a [x] -- hint\\n    one\\nd.md:5: rule-b [y] -- hint\\n    two\\n\\u0001x:1: rule-c -- hint\\n    three\\n").items;
report(pcTwice.length === 3 && pcTwice[0].id === "d.md:5" && pcTwice[1].id === "L2" && pcTwice[2].id === "L3", "prose-check: a repeated and an invalid path:line fall back to L<n>", JSON.stringify(pcTwice));
report(!isItemId("constructor") && !isItemId("prototype") && isItemId("src/a.cs:1"), "ids: the names the body reviver drops are not ids");
// A line of spaces then one character made the whole-line diagnostic pattern backtrack for seconds (3 s at 300
// spaces, 34 s at 800); the marker search reads it in the time its length costs.
const slowLine = " ".repeat(LIMITS.maxParseLineChars - 1) + "x";
const t0 = Date.now();
const fast = parseMsbuild(slowLine + "\\nreal.cs(1,2): error CS1: m\\n");
const slowMs = Date.now() - t0;
report(fast.items.length === 1 && slowMs < 1000, \`msbuild: a line of spaces parses in linear time (\${slowMs} ms)\`);

// msbuild: diagnostics are kept with the code as the rule, the summary repeat collapses, the rest is set aside.
const log = [
  "Build started 9/22/2026 10:18:09 AM.",
  "     1>Project \"/p/x.sln\" on node 1 (Restore target(s)).",
  "     2>/p/src/S/ModelProfiles.cs(236,76): error CS1061: 'X' has no definition for 'Y' [/p/src/S/S.csproj]",
  "     2>/p/src/S/Other.cs(12): warning CS0168: unused [/p/src/S/S.csproj]",
  "         /p/src/S/ModelProfiles.cs(236,76): error CS1061: 'X' has no definition for 'Y' [/p/src/S/S.csproj]",
  "    1 Error(s)",
  "x".repeat(LIMITS.maxParseLineChars + 1) + ": error CS9999: not matched, the line is over the parse bound",
].join("\\n");
const ms = parseMsbuild(log);
report(ms.items.length === 2 && ms.items[0].id === "/p/src/S/ModelProfiles.cs:236" && ms.items[0].rule === "error CS1061"
  && ms.items[0].context === "/p/src/S/S.csproj" && ms.items[1].rule === "warning CS0168" && ms.items[1].id === "/p/src/S/Other.cs:12"
  && ms.setAside === 5, "msbuild: diagnostics kept, repeat collapsed, over-long line and chatter set aside", JSON.stringify(ms));
report((() => { try { parseMsbuild("Build succeeded.\\n    0 Error(s)\\n"); return false; } catch (e) { return e.code === "input"; } })(),
  "msbuild: a log with no diagnostic is an input error naming the line count");

// Untrusted input: a binary stream is refused before a request, whatever the format.
for (const [what, text] of [["a NUL", "ok line\\n\\u0000\\u0000binary\\n"], ["control bytes", "\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\u0008".repeat(20)]]) {
  report((() => { try { parse("lines", text); return false; } catch (e) { return e.code === "input"; } })(), \`binary input refused: \${what}\`);
}
report((() => { try { parse("lines", "x".repeat(LIMITS.maxInputChars + 1)); return false; } catch (e) { return e.code === "input"; } })(),
  "input over the size bound is refused");

// An item the bound cut is counted, so a run reports evidence the model did not see.
const cutNorm = normalizeItems([{ id: "a", text: "x".repeat(LIMITS.maxItemChars + 1) }, { id: "b", text: "short" }]);
report(cutNorm.cut === 1 && cutNorm.items[0].text.includes("[...cut at"), "a cut item is counted", JSON.stringify(cutNorm.cut));
const ids = ["a", "b"];
const good = { model: "jev-1.13.0", answers: { a: { type: "noul", noul: 0.9 }, b: { type: "noul", noul: 0.1 } }, usage: { input_tokens: 10, output_tokens: 0 } };
report(contractProblems(good, ids, "noul", null).length === 0, "contract: a valid noul body passes");
const cases = [
  ["missing answer", { ...good, answers: { a: good.answers.a } }, "missing"],
  ["extra answer", { ...good, answers: { ...good.answers, c: { type: "noul", noul: 0.5 } } }, "unexpected"],
  ["noul out of range", { ...good, answers: { ...good.answers, a: { type: "noul", noul: 1.5 } } }, "[0,1]"],
  ["wrong type", { ...good, answers: { ...good.answers, a: { type: "choice", noul: 0.5 } } }, "type"],
  ["no usage", { model: "m", answers: good.answers }, "usage"],
  ["text body", "<html>", "not an object"],
  ["empty body", undefined, "not an object"],
];
for (const [what, body, needle] of cases) {
  const p = contractProblems(body, ids, "noul", null);
  report(p.length > 0 && p.some((x) => x.includes(needle)), \`contract: \${what} is reported\`, p.join("; "));
}
const opts = { rewrite: "r", keep: "k", open: "o" };
const choiceGood = { model: "m", answers: { a: { type: "choice", choice: "keep", confidence: 0.8, probabilities: { rewrite: 0.1, keep: 0.8, open: 0.1 } } }, usage: { input_tokens: 1, output_tokens: 0 } };
report(contractProblems(choiceGood, ["a"], "choice", opts).length === 0, "contract: a valid choice body passes");
const invisible = normalizeItems([{ id: "a", text: "safe\u202Ehidden" }, { id: "b", text: "plain" }, { id: "c", text: "zero\u200bwidth" }]);
report(invisible.invisible === 2 && invisible.items[0].text.includes("\u202E") && invisible.items[2].text.includes("\u200B"), "invisible formatting is counted per item and left in the text", JSON.stringify(invisible.invisible));
report((() => { try { normalizeItems([{ id: "a", text: "tag\u{E0001}here" }]); return false; } catch (e) { return e.code === "input"; } })(), "a tag character is refused rather than counted");
const rtl = normalizeItems([{ id: "a", text: "\u05E9\u05DC\u05D5\u05DD 42\u200F" }, { id: "b", text: "x\u200Ey" }, { id: "c", text: "\u0645\u0631\u062D\u0628\u0627" }, { id: "d", text: "a\u2067b\u2069" }]);
report(rtl.invisible === 1, "right-to-left text and the LRM/RLM marks are not counted; an isolate is", JSON.stringify(rtl.invisible));
const badChoice = [
  ["choice outside the options", (b) => { b.answers.a.choice = "maybe"; }, "not an option"],
  ["probabilities not summing to 1", (b) => { b.answers.a.probabilities.keep = 0.3; }, "sum to"],
  ["choice not the argmax", (b) => { b.answers.a.probabilities = { rewrite: 0.8, keep: 0.1, open: 0.1 }; }, "highest-probability"],
  ["a missing option key", (b) => { delete b.answers.a.probabilities.open; b.answers.a.probabilities.keep = 0.9; }, "keys differ"],
  ["confidence out of range", (b) => { b.answers.a.confidence = 2; }, "confidence"],
];
for (const [what, mutate, needle] of badChoice) {
  const b = structuredClone(choiceGood); mutate(b);
  const p = contractProblems(b, ["a"], "choice", opts);
  report(p.length > 0 && p.some((x) => x.includes(needle)), \`contract: \${what} is reported\`, p.join("; "));
}
// Pinning: hostile SDK fallbacks in the environment do not change the origin, the bearer or the model.
process.env.TYPESAFE_API_KEY = "env_key_must_not_be_used_0123456789";
process.env.TYPESAFE_BASE_URL = "https://doesnotexist.invalid";
process.env.TYPESAFE_DEFAULT_MODEL = "env-model";
const config = readConfig("${conf}");
report(config.threshold === 0.5 && config.uncertainBand[0] === 0.35 && config.uncertainBand[1] === 0.65 && config.timeoutMs === 15000, "defaults: a file omitting them yields the threshold, band and timeout from defaults.mts");
const calls = [];
const fetchImpl = async (url, init) => {
  calls.push({ url, auth: init.headers.Authorization ?? init.headers.authorization, body: JSON.parse(init.body), redirect: init.redirect });
  return new Response(JSON.stringify({ model: "jev-1.13.0", answers: { "s:1": { type: "noul", noul: 0.9 }, "s:2": { type: "noul", noul: 0.2 } }, usage: { input_tokens: 5, output_tokens: 0 } }), { status: 200, headers: { "content-type": "application/json", "x-typesafe-request-id": "req_unit" } });
};
const client = makeClient(config, fetchImpl);
const d = await decideFilter(client, filter, [{ id: "s:1", text: "one" }, { id: "s:2", text: "two" }], { task: "t" });
const c = calls[0];
report(c.url === "https://api.typesafe.ai/v1/systemone", "pinning: the request goes to the configured origin, not TYPESAFE_BASE_URL", c.url);
report(c.auth === "Bearer ${KEY}", "pinning: the bearer is the file's key, not TYPESAFE_API_KEY");
report(c.body.model === "jev-1.13.0", "pinning: the model is the file's default, not TYPESAFE_DEFAULT_MODEL", c.body.model);
report(c.redirect === "manual", "pinning: a redirect is not followed, so the key and the listing go to the origin alone", String(c.redirect));
report(Object.keys(c.body.questions).join() === "s:1,s:2" && c.body.questions["s:1"].type === "noul" && c.body.state.task === "t", "request: one noul per item keyed by id, the task in the state");
report(d.kept.length === 1 && d.dropped.length === 1 && d.requests[0].requestId === "req_unit" && d.requests[0].inputTokens === 5, "decision: kept/dropped split, request id and usage reported", JSON.stringify(d));
const err401 = async () => { try { await decideFilter(makeClient(config, async () => new Response("{}", { status: 401, headers: { "content-type": "application/json" } })), filter, [{ id: "a", text: "x" }], { task: "t" }); return null; } catch (e) { return e; } };
const e = await err401();
report(e && e.code === "provider" && e.exitStatus === 4 && e.detail.status === 401 && !e.describe().includes("${KEY}"), "errors: a 401 maps to the provider class, exit 4, no key in the line", e ? e.describe() : "none");
// Everything the provider sends is untrusted: each of these answers is refused at its gate, with one fetch made.
const refused = async (what, respond, code, needle) => {
  let n = 0;
  try { await decideFilter(makeClient(config, async () => { n++; return respond(); }), filter, [{ id: "a", text: "x" }], { task: "t" }); report(false, \`gate: \${what}\`, "accepted"); }
  catch (e) { report(e.code === code && n === 1 && e.describe().includes(needle), \`gate: \${what} is refused as \${code}\`, \`\${e.describe()} after \${n} fetch(es)\`); }
};
const json = (body, headers = {}) => new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json", ...headers } });
await refused("a 302 to another host", () => new Response("", { status: 302, headers: { location: "https://elsewhere.invalid/" } }), "provider", "302");
await refused("a subtype that only starts with json", () => new Response("{}", { status: 200, headers: { "content-type": "application/jsonx" } }), "contract", "not JSON");
await refused("a model name carrying a line break", () => json({ model: "jev\\n1", answers: { a: { type: "noul", noul: 0.5 } }, usage: { input_tokens: 1, output_tokens: 0 } }), "contract", "model");
await refused("a body snippet carrying an escape sequence", () => new Response("\\u001b[31mnope\\u001b[0m\\nsecond line", { status: 400, headers: { "content-type": "text/plain" } }), "provider", "400");
report((await (async () => { try { await decideFilter(makeClient(config, async () => new Response("\\u001b[2Jx", { status: 400 })), filter, [{ id: "a", text: "x" }], { task: "t" }); return ""; } catch (e) { return e.describe(); } })()).match(/[\\u0000-\\u001f]/) === null, "errors: the described line holds no control character from the body");
const pre = new AbortController(); pre.abort(new Error("caller cancelled"));
let fetched = 0;
const cancelled = await (async () => { try { await decideFilter(makeClient(config, async () => { fetched++; return json({}); }), filter, [{ id: "a", text: "x" }], { task: "t" }, { signal: pre.signal }); return null; } catch (e) { return e; } })();
report(cancelled && cancelled.code === "deadline" && fetched === 0, "deadline: a signal aborted before the call makes no request", cancelled ? cancelled.describe() : "none");
EOF
set +e
drive_out="$(node "${TESTDIR}/drive.mjs" 2>&1)"; drive_rc=$?
set -e
if [[ ${drive_rc} -ne 0 ]]; then
    fail "the library driver crashed: $(head -c 300 <<<"${drive_out}" | tr '\n' '|')"
else
    while IFS= read -r line; do
        case "${line}" in
            "ok "*) pass "${line#ok }" ;;
            "FAIL "*) fail "${line#FAIL }" ;;
            *) fail "unexpected driver output: ${line}" ;;
        esac
    done <<<"${drive_out}"
fi

finish
