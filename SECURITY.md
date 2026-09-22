# Security

Report vulnerabilities privately via this repository's **Security** tab
→ *Report a vulnerability*. Do not open a public issue.

## Scope

This is an unofficial client. Issues in the TypeSafe service, its API, or
its official SDK belong at [typesafe.ai](https://typesafe.ai/), not here.

Report here only problems in this client's handling of:

- credentials (logs, errors, argv, environment, wrong host)
- responses that bypass the checks in `transport.mts`
- config files accepted by `config.mts` that should be rejected
- input that exceeds the bounds enforced in `core.mts`, or a line that makes
  a parser in `parsers.mts` take more than linear time

## Supported versions

Latest tag only. Pre-1.0; fixes land on `main` and the next tag.
No backports. Consumers who pin a release tarball must update the pin
themselves.
