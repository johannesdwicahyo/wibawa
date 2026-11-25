# Security Policy

Wibawa is an admin panel: a flaw in it can expose or change an application's data. Reports are taken seriously.

## Supported versions

Wibawa has not had its first release. Until 1.0, security fixes go into the newest release only.

## Reporting a vulnerability

**Do not open a public issue.** Use GitHub's private reporting instead: on the repository, open the **Security** tab and choose **Report a vulnerability** ([direct link](https://github.com/johannesdwicahyo/wibawa/security/advisories/new)). Only the maintainer sees the report.

Please include:

- the Wibawa and Rails versions,
- what an attacker can do and what they need to do it (signed in or not, which permissions),
- steps or a small example that shows it.

## What to expect

- An acknowledgement within 7 days.
- An assessment and, if the report is confirmed, a plan for the fix within 30 days.
- Credit in the release notes when the fix ships, unless you prefer not to be named.

Please give the maintainer a reasonable time to release a fix before publishing details.

## Scope

In scope: anything that lets someone read or change data they should not, through the admin pages, the MCP endpoint, CSV import or export, or reports. For example: a missing authorization check, a way around a policy scope, SQL injection, cross-site scripting, or CSV formula injection.

Out of scope: an application that mounts Wibawa without configuring authentication or authorization, and SQL that a developer wrote into their own report.
