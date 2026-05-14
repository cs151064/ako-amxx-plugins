# Third-party Plugins

Put external AMXX plugin sources here when you want to keep them separate from Ako plugins.

- `src/`: third-party `.sma` files
- `include/`: third-party `.inc` files needed only by third-party plugins
- `resources/`: files copied into `cstrike/` during third-party deploy
- `plugins.local.ini`: optional third-party plugin order for `plugins.ini`

Build these with `.\amxx-dev.ps1 -Action Build -ThirdParty`.
