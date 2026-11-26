# Contributing to Wibawa

Thanks for helping. Bug reports, fixes, translations and documentation are all welcome.

## Before you start

- **A bug:** open an issue with the steps, what you expected and what happened. A failing spec is the best report.
- **A feature:** open an issue first. Wibawa stays small on purpose, and `ROADMAP.md` lists what is planned; agreeing on the idea saves you writing something that will not be merged.
- **A security problem:** do not open a public issue. See `SECURITY.md`.

## Setting up

You need Ruby 3.2 or newer, Node (CI uses 22), and Chrome or Chromium (the browser specs drive it).

```sh
git clone https://github.com/johannesdwicahyo/wibawa && cd wibawa
bundle install
npm install
bundle exec rake        # style check, specs, Sprockets check, demo check
bundle exec rake demo   # the demo admin at http://localhost:3000/admin
```

To run the suite against another Rails version: `RAILS_VERSION=7.2 bundle update && bundle exec rake` (7.2, 8.0 and 8.1 are supported).

## Making a change

1. Branch from `main`. Changes reach `main` only through a pull request.
2. Add or update a spec. Request specs live in `spec/requests`, browser specs in `spec/system`, and specs of the DSL that need no database in `spec/unit`.
3. If you changed any CSS class in a component, view or helper, run `npm run build:css` and commit `app/assets/builds/wibawa.css`. CI fails when it is out of date.
4. Run `bundle exec rake`. It must pass, style check included (`bundle exec rubocop -a` fixes most style offenses).
5. Add a line to `CHANGELOG.md` under the unreleased version if users will notice the change.
6. Open the pull request and say what you changed, how you checked it, and what you did not check.

## What a change should look like

- **Design:** `DESIGN.md` is the specification for anything visual: colors come from tokens, nothing under 13 px, one primary button per page. New screens are checked at 390 px and 1440 px in both themes.
- **Accessibility:** new pages belong in `spec/system/accessibility_spec.rb`, and everything a pointer can do must work from the keyboard.
- **Translations:** every string goes in `config/locales/en.yml` and in every other file there. `spec/unit/locales_spec.rb` fails if a locale is missing a key, has one English lacks, leaves a text empty or uses different `%{variables}`, and if the code asks for a key English does not define or English keeps one the code never uses. To add a language, copy `en.yml` to `<code>.yml`, change the top key, and translate; the spec picks the file up by itself.
- **Dependencies:** Wibawa has no JavaScript dependencies and few Ruby ones. A new runtime dependency needs a strong reason; say what it is in the pull request.
- **Scope:** one change per pull request. A refactor and a feature are two pull requests.

## Conduct

Everyone taking part is expected to follow the `CODE_OF_CONDUCT.md`.
