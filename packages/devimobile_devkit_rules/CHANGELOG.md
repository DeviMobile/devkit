# Changelog

## [0.1.1](https://github.com/DeviMobile/devkit/compare/devimobile_devkit_rules-v0.1.0...devimobile_devkit_rules-v0.1.1) (2026-11-07)


### Features

* **rules:** add devimobile_devkit_rules 0.1.0 ([#2](https://github.com/DeviMobile/devkit/issues/2)) ([640029f](https://github.com/DeviMobile/devkit/commit/640029fe278068c59c062f34599d6ada269ed73a))
* **rules:** skip the design system package (configurable) ([#3](https://github.com/DeviMobile/devkit/issues/3)) ([3595929](https://github.com/DeviMobile/devkit/commit/35959299b67571ea424d2c40949d4303ef9a2b7b))

## 0.1.0

- Initial release: analyzer plugin with the rules `avoid_color_literals`,
  `avoid_material_colors`, `avoid_edge_insets_literals`,
  `avoid_sized_box_literals` and `avoid_ui_string_literals`, and a quick fix
  that replaces all-zero insets with `EdgeInsets.zero`.
- The rules skip design system packages, `design_system` by default or the
  names under `devimobile_devkit_rules: design_system_packages:` in
  `analysis_options.yaml`, followed through `include:`.
