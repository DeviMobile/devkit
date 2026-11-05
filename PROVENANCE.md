# Provenance

Everything in this repository is written by its contributors. We do not copy
code, configuration files or documentation from other projects.

- **Requirements** come from our own needs, the Dart and Flutter SDK
  documentation and the SDK's machine-readable lint catalog
  (`pkg/linter/tool/machine/rules.json` in the Dart SDK repository).
- **Lint decisions** are made rule by rule from the SDK catalog, each with our
  own reason (`packages/devimobile_devkit_lints/RULES.md`). We do not start
  from, or compare against, another project's rule list.
- **Names** of commands, options, configuration keys and messages are our own.
- **Third-party code** enters only as a declared dependency in `pubspec.yaml`,
  under its own license.

Every pull request confirms these rules in its checklist.
