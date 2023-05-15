# Changelog

## [4.3.0](https://github.com/nvim-neorg/neorg/compare/v4.2.0...v4.3.0) (2023-05-15)


### Features

* **calendar:** add `t` command for "today" ([e53a509](https://github.com/nvim-neorg/neorg/commit/e53a5099b5725162c8f0a626823cac4819a9427d))
* **hop:** allow users to jump to timestamps ([22b12fb](https://github.com/nvim-neorg/neorg/commit/22b12fb2301582fd9552ab10ac0c934cda4d0a14))


### Bug Fixes

* **hop:** assume &lt;current-day&gt; when some parameters to dates are not supplied ([65bf064](https://github.com/nvim-neorg/neorg/commit/65bf06493ecb411b1589ad345771ae29aa17cd33))
* **tempus:** days like `4th`/`2nd` would not get parsed properly ([7368a8a](https://github.com/nvim-neorg/neorg/commit/7368a8ae10a0bab32729bd00dcac6f24cb55a8ef))

## [4.2.0](https://github.com/nvim-neorg/neorg/compare/v4.1.1...v4.2.0) (2023-05-15)


### Features

* **tempus:** add `,id` (insert date) keybinding ([34f13ba](https://github.com/nvim-neorg/neorg/commit/34f13ba253c160e72ef7817a950508430ed050d1))
* **tempus:** add insert mode `&lt;M-d&gt;` keybind to insert a date ([b420f69](https://github.com/nvim-neorg/neorg/commit/b420f69602b23fa8fc2f7f6526f49838f9521b10))
* **tempus:** allow dates to be converted to norg-compatible dates with `tostring()` ([3ec5f96](https://github.com/nvim-neorg/neorg/commit/3ec5f96dfd673c2c2a34b09748518accf61ec677))


### Bug Fixes

* don't allow tempus to load unless the Neovim ver is at least 0.10.0 ([c4429fa](https://github.com/nvim-neorg/neorg/commit/c4429fa1e1eb0c3c5652495b00aa4e1c56068914))
* **tempus:** do not assume `osdate` has all fields set ([c37a104](https://github.com/nvim-neorg/neorg/commit/c37a104c992326f8924de783d667f7c4c34f92b7))

## [4.1.1](https://github.com/nvim-neorg/neorg/compare/v4.1.0...v4.1.1) (2023-05-15)


### Bug Fixes

* remove calendar as a dependency of `core.ui`, fix errors for people not on nightly ([cd26a22](https://github.com/nvim-neorg/neorg/commit/cd26a220e999cc9103a2502299d16ae8e6fab4d9))

## [4.1.0](https://github.com/nvim-neorg/neorg/compare/v4.0.1...v4.1.0) (2023-05-14)


### Features

* add `core.tempus` module for date management ([b73ec2f](https://github.com/nvim-neorg/neorg/commit/b73ec2f5e1b11864ca0628a842a53a617d5851ce))
* add left-right cursor movement ([ea588bb](https://github.com/nvim-neorg/neorg/commit/ea588bbc2cabe37f90652a8cb49bf8b286498d2a))
* add skeleton for the calendar UI element ([3c99106](https://github.com/nvim-neorg/neorg/commit/3c99106d64792533a3cf10ac6ef20a089e94c1ff))
* **calendar:** add `?` help page for custom input ([211b0ba](https://github.com/nvim-neorg/neorg/commit/211b0ba61b5cf8f4520b5e03f5235f6de87e4417))
* **calendar:** add `$` and `0`/`_` navigation keybinds ([0061928](https://github.com/nvim-neorg/neorg/commit/006192808d436c27f8ceca0fffcc4a238ec402a7))
* **calendar:** add `m`/`M`, `L`/`H` and `y`/`Y` keybinds for the monthly view ([9bf562d](https://github.com/nvim-neorg/neorg/commit/9bf562d4633abac71b749ad7380cfe010a4c3bd7))
* **calendar:** add basic help popup when `?` is invoked ([779d089](https://github.com/nvim-neorg/neorg/commit/779d089e17139acfdd2a4988c34eea892f29a475))
* **calendar:** allow many simultaneous calendars ([f816fe7](https://github.com/nvim-neorg/neorg/commit/f816fe77ef2abecff9e98d8d35ff48a453317cf0))
* **calendar:** generalize functions even further, allow for offsets ([d857c34](https://github.com/nvim-neorg/neorg/commit/d857c34fe7a4645501551f2b66dd7915b9575b4f))
* **calendar:** implement basic `i` functionality ([6713f40](https://github.com/nvim-neorg/neorg/commit/6713f40d5d1f9e7a0e8b80ffdc82d4fff79c16c0))
* **calendar:** render as many months as is possible on screen ([fa23767](https://github.com/nvim-neorg/neorg/commit/fa237674cf75bf2bbc62a438b1606b65cc277ebd))
* **core.ui.calendar:** add day of the month rendering ([8bc3364](https://github.com/nvim-neorg/neorg/commit/8bc3364f306d5df528193a8ca68fa8b4a45701ef))
* **core.ui.calendar:** add static calendar ui ([adbb415](https://github.com/nvim-neorg/neorg/commit/adbb4151677bf22c809f9b6dfd35de5e07da6c7a))
* **core.ui.calendar:** highlight the current day differently ([eada386](https://github.com/nvim-neorg/neorg/commit/eada386cc79c122b648580de50b1f825b74a9627))
* **core.ui.calendar:** implement more of the barebones UI ([364f44a](https://github.com/nvim-neorg/neorg/commit/364f44a7d1179d5aa98d1f4ff6b4b6b1b6078bd3))
* **core.ui.calendar:** make the calendar display full month names ([c6cc059](https://github.com/nvim-neorg/neorg/commit/c6cc059992c812712c9a2bb4075b2d9b31f84f5c))
* **core.ui:** let `create_split` take in a `height` variable ([7dbbe9d](https://github.com/nvim-neorg/neorg/commit/7dbbe9d236596d8990827e717ea892cd98e79b23))
* correctly handle year boundaries ([58b55e1](https://github.com/nvim-neorg/neorg/commit/58b55e16366ecd431bece7ba4d42d512b21b972e))
* implement `render_month` function ([343fb8d](https://github.com/nvim-neorg/neorg/commit/343fb8d02422fe2f2a3c791f2bdba0be95c3c96b))
* place cursor over current day when creating calendar ([3ce268b](https://github.com/nvim-neorg/neorg/commit/3ce268b703d321561b86e546c7633326b39fa494))
* **tempus:** add `to_lua_date` function ([ef62e53](https://github.com/nvim-neorg/neorg/commit/ef62e5308c684468a822684382d14de8f8f63193))


### Bug Fixes

* **calendar:** allow the view to be written to on rerender ([8e247d4](https://github.com/nvim-neorg/neorg/commit/8e247d414bcb0d1123b2b12c7ff29bdf36c50cbd))
* **calendar:** fix incorrect movement with `H` across boundaries of months with different lengths ([48face2](https://github.com/nvim-neorg/neorg/commit/48face25855d7844302b13a125363c30b8a6fe9a))
* **calendar:** fix rest of highlight groups ([ead4c4c](https://github.com/nvim-neorg/neorg/commit/ead4c4c53769839b5063fab71ebb92d155d53676))
* **calendar:** if another calendar is open then close it instead of erroring ([9751e7d](https://github.com/nvim-neorg/neorg/commit/9751e7d62af0b7e49ff788058154b966be205e2e))
* **calendar:** make distance between each month uniform and support modifying the distance between each month ([746354d](https://github.com/nvim-neorg/neorg/commit/746354dea70e9657f61531375329e407e7f5a203))
* **calendar:** make month rendering work again ([164028f](https://github.com/nvim-neorg/neorg/commit/164028fd621e3c5b56603d88d6d5e2ba5db51d42))
* **calendar:** overlapping month names in the calendar view ([709cf78](https://github.com/nvim-neorg/neorg/commit/709cf78410b6ea631192ad004d3f2b83761f9953))
* **calendar:** prevent the buffer from being modifiable after it has been filled ([351e103](https://github.com/nvim-neorg/neorg/commit/351e10326e0e2bb6166e165ddb6598e917e6d25c))
* **calendar:** properly display "today's day" in the calendar view ([74ee71a](https://github.com/nvim-neorg/neorg/commit/74ee71a446662f92afa3cbd49f6c980bdf25ae92))
* **calendar:** reversed namespace names ([77b214c](https://github.com/nvim-neorg/neorg/commit/77b214cef220580cdcf527265a15ef980e7bcaf3))
* **core.ui.calendar:** logic error when parsing virt_text length for `set_logical_extmark` ([d5b29ee](https://github.com/nvim-neorg/neorg/commit/d5b29eea8e09d7bd0add778c6818539719914301))
* **core.ui.calendar:** wrong extmark being queried in month render routine ([46624b9](https://github.com/nvim-neorg/neorg/commit/46624b9a02e0d0e928026a0fd4852c4dd3ca7e0d))

## [4.0.1](https://github.com/nvim-neorg/neorg/compare/v4.0.0...v4.0.1) (2023-05-11)


### Bug Fixes

* **highlights.scm:** free form open/close chars would not be concealed ([5de014e](https://github.com/nvim-neorg/neorg/commit/5de014e7cc3dc6eed0a62854fe8ba58f664d97ea))
* **qol.toc:** display headings with TODO statuses unless the status is "cancelled" ([2e44346](https://github.com/nvim-neorg/neorg/commit/2e44346813310de9afc411e2348cf2be8540f70c))
* stop syntax processing if a buffer is already closed ([#859](https://github.com/nvim-neorg/neorg/issues/859)) ([cc2834a](https://github.com/nvim-neorg/neorg/commit/cc2834ae2beb2d5baa75d15848a94dae022faa2c))

## [4.0.0](https://github.com/nvim-neorg/neorg/compare/v3.2.2...v4.0.0) (2023-05-05)


### ⚠ BREAKING CHANGES

* move all `gt*` keybinds to `<LocalLeader>t*`
* remove `core.news`

### Features

* add basic cheatsheet (viewable via `:h neorg-cheatsheet`) ([d3e37a6](https://github.com/nvim-neorg/neorg/commit/d3e37a681743181a34dcfa7adb6ec61fb5aeb63c))
* **keybinds:** warn when a deprecated keybind is used (will be removed with `5.0`) ([e20d3c3](https://github.com/nvim-neorg/neorg/commit/e20d3c324b091cac29ccd7ec8431d24aa9b792c8))


### Bug Fixes

* **concealer:** buggy debounce logic causing visual artifacts (especially on the first line of a buffer) ([45388fc](https://github.com/nvim-neorg/neorg/commit/45388fc0478e8d1273bd80789e7e1af1df76458f))
* **concealer:** stop concealer if buffer is not loaded ([#836](https://github.com/nvim-neorg/neorg/issues/836)) ([6aa9fd3](https://github.com/nvim-neorg/neorg/commit/6aa9fd303c807ed1ca3fb15cdeab1e322d02fd31))
* **dirman.expand_path:** search for both `$/` and `$\` in links to support windows paths ([#830](https://github.com/nvim-neorg/neorg/issues/830)) ([160d40f](https://github.com/nvim-neorg/neorg/commit/160d40f5261be5149842942adbf260d6e359d9ec))
* **esupports.hop:** anchors to files woul dresult in a "link not found" ([#688](https://github.com/nvim-neorg/neorg/issues/688)) ([3009adf](https://github.com/nvim-neorg/neorg/commit/3009adf2cf48aedcbb309d0765e0fbbb64a0fdf4))
* **keybinds.lua:** remove dead `toc` keybinds ([06666f2](https://github.com/nvim-neorg/neorg/commit/06666f298e146d758d691366ca3465a3bd1e3f7f))


### Code Refactoring

* move all `gt*` keybinds to `&lt;LocalLeader&gt;t*` ([f67110d](https://github.com/nvim-neorg/neorg/commit/f67110d11d37fde09756eb2de8a1814d04a4a03b))
* remove `core.news` ([4086d9f](https://github.com/nvim-neorg/neorg/commit/4086d9f17d823cfe5a13e7b12b30e13b5d3b796d))

## [3.2.2](https://github.com/nvim-neorg/neorg/compare/v3.2.1...v3.2.2) (2023-04-27)


### Bug Fixes

* **core.ui:** clear the `winbar` option in Neorg popups to prevent "not enough room" errors ([fcebf9f](https://github.com/nvim-neorg/neorg/commit/fcebf9f6caf0667f99b1481e2c0a49f0eeb68fe9))
* **esupports.hop:** broken definitions and footnotes ([#733](https://github.com/nvim-neorg/neorg/issues/733)) ([94cf7d2](https://github.com/nvim-neorg/neorg/commit/94cf7d2889b386ce1313e80c8c04adf18872c028))

## [3.2.1](https://github.com/nvim-neorg/neorg/compare/v3.2.0...v3.2.1) (2023-04-27)


### Bug Fixes

* **export:** `gsub` export links that contain `#`, `?`. closes [#807](https://github.com/nvim-neorg/neorg/issues/807) ([#816](https://github.com/nvim-neorg/neorg/issues/816)) ([7f3a3b8](https://github.com/nvim-neorg/neorg/commit/7f3a3b850c8d4b73e7f85971aae2a96162bcb150))
* **export:** markdown export for horizontal_line ([#820](https://github.com/nvim-neorg/neorg/issues/820)) ([2178447](https://github.com/nvim-neorg/neorg/commit/217844796e00a1cea7c051435f9c49bee25e7caa))

## [3.2.0](https://github.com/nvim-neorg/neorg/compare/v3.1.0...v3.2.0) (2023-04-22)


### Features

* add `core.pivot` for toggling list types ([cbf383f](https://github.com/nvim-neorg/neorg/commit/cbf383ff4eca0e23a24d4244af20bed415ed400c))
* **keybinds:** add default keybinds for `core.pivot` ([2f49628](https://github.com/nvim-neorg/neorg/commit/2f496283504dcfb30d9ee60101a8290e743c1753))
* **pivot:** add `core.pivot.invert-list-type` keybind ([2d0446a](https://github.com/nvim-neorg/neorg/commit/2d0446a2d8e3789bbd17bbb3cb97e73befccb327))


### Bug Fixes

* **core.summary:** wrong module name in header, wrong internal command names ([a046900](https://github.com/nvim-neorg/neorg/commit/a0469001430a68f521d3292f8a8252655cfda941))
* **docgen:** installation documentation link for wiki ([ba8b31d](https://github.com/nvim-neorg/neorg/commit/ba8b31dc2491f80b9f65fadbafdfd94d6ef26988)), closes [#548](https://github.com/nvim-neorg/neorg/issues/548)
* **summary:** broken wiki entry ([69fbabf](https://github.com/nvim-neorg/neorg/commit/69fbabfb5764cd164453a764174cf5cfa813ae60))

## [3.1.0](https://github.com/nvim-neorg/neorg/compare/v3.0.0...v3.1.0) (2023-04-19)


### Features

* warn access to `core.norg` modules instead of breaking ([ed761a5](https://github.com/nvim-neorg/neorg/commit/ed761a5c5a9100861034b31978049401444fd6fb))

## [3.0.0](https://github.com/nvim-neorg/neorg/compare/v2.0.1...v3.0.0) (2023-04-19)


### ⚠ BREAKING CHANGES

* move all `core.norg.*` modules into `core.*`
* **Makefile:** remove `install_pre_commit` target
* move `core.norg.dirman.summary` -> `core.summary`
* **summary:** refactor of the `core.norg.dirman.summary` module
* **docgen:** wipe whole wiki on every reparse

### Features

* add `dirman.summary` module ([#750](https://github.com/nvim-neorg/neorg/issues/750)) ([93c40f2](https://github.com/nvim-neorg/neorg/commit/93c40f2e38a0770e9ce95787c8363320344a87c3))
* add `Home.md` generation capability ([6bdf557](https://github.com/nvim-neorg/neorg/commit/6bdf557ece33850f9733dddc343369d743a51564))
* **ci:** add `version_in_code.yml` workflow ([5746245](https://github.com/nvim-neorg/neorg/commit/5746245756bac83fcf02338c93bc87f6089e2bf3))
* cleanup, add document comments to all modules, add more error checks ([81284c1](https://github.com/nvim-neorg/neorg/commit/81284c1e2f6e441f6532678b76ff5378396dda2c))
* **config.lua:** add `norg_version`, bump `version` to `3.0.0` ([8d76723](https://github.com/nvim-neorg/neorg/commit/8d767232a571513a3ab8c5c14ddc6f26d09aa98a))
* **core.integrations.treesitter:** Return all same attributes of a tag ([bedf13d](https://github.com/nvim-neorg/neorg/commit/bedf13dbcef63099a52dd4f160d90c46fc1de440))
* **dirman:** add new `use_popup` option for `dirman` ([#743](https://github.com/nvim-neorg/neorg/issues/743)) ([6350254](https://github.com/nvim-neorg/neorg/commit/63502544afde1c15d79ce097ad1928314cb8c7cd))
* **docgen:** add `module` page generator ([17496a8](https://github.com/nvim-neorg/neorg/commit/17496a8e975f1bd9d896d7cc78a6e61d1a131245))
* **docgen:** add basic rendering skeleton logic ([215719e](https://github.com/nvim-neorg/neorg/commit/215719ece560400592c2fef2ed75ab57430baf9b))
* **docgen:** add comment integrity checking logic ([799886f](https://github.com/nvim-neorg/neorg/commit/799886f7ba5a072a453d5a90708686109ce4fa21))
* **docgen:** allow strings as table keys ([4adf04e](https://github.com/nvim-neorg/neorg/commit/4adf04e05d98b6bcb6a3aac4cab60d64fd0d86f9))
* **docgen:** auto-open &lt;details&gt; tags that contain tables or lists ([1f2e0dc](https://github.com/nvim-neorg/neorg/commit/1f2e0dc23f6944bad660553ad4550847cf68e096))
* **docgen:** differentiate between lists and tables ([c0062e5](https://github.com/nvim-neorg/neorg/commit/c0062e5a75226f063b59eb5ee8250cb4da6ea202))
* **docgen:** differentiate empty and nonempty tables/lists ([0ab1a8d](https://github.com/nvim-neorg/neorg/commit/0ab1a8d469667d6b763e299c390a3e9bc7ea1a13))
* **docgen:** implement `Required By` field ([7033c4b](https://github.com/nvim-neorg/neorg/commit/7033c4bd2dc4633d0874b2da05b0ae67928b1117))
* **docgen:** implement `Required By` section ([15bf71b](https://github.com/nvim-neorg/neorg/commit/15bf71b15e07917e0f3a55de44e79fcdfbfc557d))
* **docgen:** implement configuration_options parsing logic ([b34658a](https://github.com/nvim-neorg/neorg/commit/b34658a21602fdd286889c2e57bf2d68d63d4472))
* **docgen:** implement function rendering, fix incorrect interpretation of function calls ([a023488](https://github.com/nvim-neorg/neorg/commit/a023488944473dfcd611308d5e21b7a9b2d7690d))
* **docgen:** implement table rendering ([9074328](https://github.com/nvim-neorg/neorg/commit/907432885e40a16f064d4406cd45efeb895f0962))
* **docgen:** indent nested table keys ([9cf679a](https://github.com/nvim-neorg/neorg/commit/9cf679a24f3bb9db145ae4dfbeb43878a49839e3))
* **docgen:** massive structure changes, implement proper table rendering ([42b8728](https://github.com/nvim-neorg/neorg/commit/42b8728f291072b9d8a11bdf9c7e205ef15fb94d))
* **docgen:** parse config tables ([93c41e1](https://github.com/nvim-neorg/neorg/commit/93c41e1f0aa290d0ad2e2590753312c71a782395))
* **docgen:** perform `[@module](https://github.com/module)` lookups, pasre complex data structures like tables ([19f2381](https://github.com/nvim-neorg/neorg/commit/19f23811ba0366fe3ec9423d26aec33d9d34fcc2))
* **docgen:** properly implement recursive table scanning ([33e06b8](https://github.com/nvim-neorg/neorg/commit/33e06b8d0fc2e7a9b386fc95e6bce4dfb714e56f))
* **docgen:** sort entries when rendering ([b420e70](https://github.com/nvim-neorg/neorg/commit/b420e70532766475bce0bf1d34129e711a31e21a))
* **docgen:** start generating true module pages ([5115d5c](https://github.com/nvim-neorg/neorg/commit/5115d5cd4bd1fefb11f82cb3e3da18b74d4e9b9e))
* **helpers/lib:** add `read_files` and `title` functions ([d59f41b](https://github.com/nvim-neorg/neorg/commit/d59f41b78755b102a41d172d4e3f64d59cb86b8b))
* **helpers:** add `ensure_nested` function ([2c4e8d0](https://github.com/nvim-neorg/neorg/commit/2c4e8d02feb7f1e6878307e7813a9f13ec000a73))
* **helpers:** Add wrapper to vim.notify ([#778](https://github.com/nvim-neorg/neorg/issues/778)) ([c278f6f](https://github.com/nvim-neorg/neorg/commit/c278f6f895c6b2f9ef4fc217ed867675108d804e))
* implement _Sidebar generation ([733b74c](https://github.com/nvim-neorg/neorg/commit/733b74c92481bc955f1f46594e50fb4931ab3cf5))
* implement necessary APIs for complex data structure parsing ([b78f01c](https://github.com/nvim-neorg/neorg/commit/b78f01cd951b8ecfe7e842d31f609e6e4d5ac9db))
* implement new docgen featuring top-comment validation ([b77fbd5](https://github.com/nvim-neorg/neorg/commit/b77fbd52f96db049687901ac1f0a8aea7ab4bdfa))
* **indent:** adapt indentation of nestable detached modifiers when a detached modifier extension is found ([56e59da](https://github.com/nvim-neorg/neorg/commit/56e59daff56ba7f4d76b11ff3fc6dd70c4b54524))
* **makefile:** add `local-documentation` option ([ed20f79](https://github.com/nvim-neorg/neorg/commit/ed20f796f5bb337d230f5d33a3f6ba420a8d30a4))
* **qol.todo_items:** add new `create_todo_items` option ([d810aa4](https://github.com/nvim-neorg/neorg/commit/d810aa43c96301db35af351306eab54e35071d57))
* **qol.todo_items:** add new `create_todo_parents` option (false by default) ([6b6ef04](https://github.com/nvim-neorg/neorg/commit/6b6ef04e5fb0a5b1c3ff59699a9371afd659d9ff))
* **qol.todo_items:** when only done and uncertain items are present in ([1d6b0b0](https://github.com/nvim-neorg/neorg/commit/1d6b0b056b097e9f4bacf8877c49fdacbc445b2c))
* strip leading `--` from comments ([ecea630](https://github.com/nvim-neorg/neorg/commit/ecea6305a82007b6c8c509fd594f8b52c3331021))
* **summary:** implement `metadata` strategy and reimplement summary generation code ([f948288](https://github.com/nvim-neorg/neorg/commit/f9482881315d49d0a35206c7936a7f48c20dfcbf))
* **toc:** add `close_after_use` configuration option ([#785](https://github.com/nvim-neorg/neorg/issues/785)) ([e5d7fbb](https://github.com/nvim-neorg/neorg/commit/e5d7fbb0291e658f78545c29318c9162cf505d15))


### Bug Fixes

* `:Neorg journal today` would fail on alternative path separators ([#749](https://github.com/nvim-neorg/neorg/issues/749)) ([e7a5054](https://github.com/nvim-neorg/neorg/commit/e7a50542ad9921a8c7d652eeca6a9006cc024b79))
* **base.lua:** don't assign the `extension` flag to parent modules, only to the imports themselves ([fa5f561](https://github.com/nvim-neorg/neorg/commit/fa5f56163510eb00a0d75bec81d40d901c175d3b))
* **clipboard.code-blocks:** don't cut off characters from non-visual-line selection ([744ae49](https://github.com/nvim-neorg/neorg/commit/744ae49fe5fab9e54de96282778a202f85a2f37b))
* **code.looking-glass:** Use last attribute as start row of looking-glass (fix [#777](https://github.com/nvim-neorg/neorg/issues/777)) ([beef6fd](https://github.com/nvim-neorg/neorg/commit/beef6fd9420d6a798ddd796779b96f006b14ca12))
* **commands.return:** don't override the workspace to `default` after running `:Neorg return` ([169c7be](https://github.com/nvim-neorg/neorg/commit/169c7bee8a5f101c63c3a473a577dce079f7ddec))
* **concealer:** whenever running any scheduled command ensure that the buffer exists first ([b926416](https://github.com/nvim-neorg/neorg/commit/b9264161d0ef10ee61ace6ebeb0a55ca461b638a))
* **core.clipboard.code-blocks:** module would not work past version `1.0.0` ([ac88283](https://github.com/nvim-neorg/neorg/commit/ac8828369cb2a4b2e1e17e6b495645585ed2a37b))
* **core.clipboard.code-blocks:** visual selection would cut off one character too little ([87ed4bf](https://github.com/nvim-neorg/neorg/commit/87ed4bfde4a00a4cf4279298de02280bf11c7a74))
* **core.export.markdown:** Update markdown exporter for new todo syntax (fix [#757](https://github.com/nvim-neorg/neorg/issues/757)) ([336416f](https://github.com/nvim-neorg/neorg/commit/336416f6c41777a4025cc80b8a085e21e758931f))
* **core.itero:** preserve indentation on continued items ([92c31c4](https://github.com/nvim-neorg/neorg/commit/92c31c491caedd7d1a82b42d4ba6c2227c05d930))
* **core.norg.esupports.hop:** Make hop on anchors work again ([#756](https://github.com/nvim-neorg/neorg/issues/756)) ([d38a229](https://github.com/nvim-neorg/neorg/commit/d38a22940aaa55351cd4dc106540fa302fad4f0d))
* **core.norg.journal:** fixes [#736](https://github.com/nvim-neorg/neorg/issues/736) , now generates TOC correctly ([19c5558](https://github.com/nvim-neorg/neorg/commit/19c555836bc31f482e0ea42f08d150110754644f))
* **core.promo:** don't error when the concealer is not loaded ([#767](https://github.com/nvim-neorg/neorg/issues/767)) ([3e09f69](https://github.com/nvim-neorg/neorg/commit/3e09f698b8a4151f2b4f77ee917e4b54388bc97a))
* **dirman:** automatically create the index file if it exists when running `:Neorg index` ([7ce2db5](https://github.com/nvim-neorg/neorg/commit/7ce2db5d2eeec37b4a4c4bc43009c4741c3755da))
* **dirman:** corrected win width and height calculation ([9766bef](https://github.com/nvim-neorg/neorg/commit/9766bef893ec993af9408ea0d44a8f13adbd1e80))
* **dirman:** don't create `index.norg` files in the default workspace when running `:Neorg index` ([c60747f](https://github.com/nvim-neorg/neorg/commit/c60747fcc567d7eb50b16c2007bcfd3a81a934d1))
* **docgen:** `&lt;h6&gt;` tags not being rendered properly ([d0a0da0](https://github.com/nvim-neorg/neorg/commit/d0a0da017135b48c5f4a325bfaedbcdf1ca79fe3))
* **docgen:** could not find module `neorg` ([b68a945](https://github.com/nvim-neorg/neorg/commit/b68a945d6b1a8c2f8c57e0c366f224a162f391e3))
* **docgen:** display listed modules in alphabetical order ([264b451](https://github.com/nvim-neorg/neorg/commit/264b451d74d3e4bc3f856d087070b9dac46f8e90))
* **docgen:** don't double-render numeric values ([35df191](https://github.com/nvim-neorg/neorg/commit/35df1918de321617972f10edd88d9c32cc8102a2))
* **docgen:** don't render description tags if no description is present ([64dc28d](https://github.com/nvim-neorg/neorg/commit/64dc28deea9a7f9c52c3ba5343f1ce3c754a566e))
* **docgen:** don't unnecessarily copy parsers ([46e7936](https://github.com/nvim-neorg/neorg/commit/46e79366775136592540fbe5f0532c001012daa5))
* **docgen:** incorrect wiki paths ([2dbead6](https://github.com/nvim-neorg/neorg/commit/2dbead687053610147161ecda1a908070720731f))
* **docgen:** internal modules that were part of `core.defaults` would not be displayed in the developer modules section ([c3099eb](https://github.com/nvim-neorg/neorg/commit/c3099ebd595d3ec491613c297f4199e316f85853))
* **docgen:** list items with no summary would break rendering ([b69ea57](https://github.com/nvim-neorg/neorg/commit/b69ea57029a2c62e72ea86c93d295102059c58ab))
* **docgen:** lists within lists would never be rendered ([06894bb](https://github.com/nvim-neorg/neorg/commit/06894bb090ad6deb52ba7b19f7e13bbb41385a63))
* **docgen:** make the spacing nicer to look at ([426ca24](https://github.com/nvim-neorg/neorg/commit/426ca246e310a212cef5f6bba367d7ebc84bf70b))
* **docgen:** remove debug log ([8ffcaed](https://github.com/nvim-neorg/neorg/commit/8ffcaed1095743b8474a16f25855b809cf4fe65d))
* **docgen:** this should work now i think (after 20 tries) ([72d3d49](https://github.com/nvim-neorg/neorg/commit/72d3d4981d85fd1114d3185e40cc135a7892a4a4))
* **docgen:** use minimal_init.vim instead of custom_init.vim ([a7cb7ab](https://github.com/nvim-neorg/neorg/commit/a7cb7ab443c24fbd1d9f696abddd91c16f05d842))
* **docgen:** wrong `require` order in `docgen.lua` ([7494b51](https://github.com/nvim-neorg/neorg/commit/7494b51a61cc31371514cb7b2e1ccdf4cef164e2))
* finalize `version_in_code.yml` CI (it works yay) ([db9ed0b](https://github.com/nvim-neorg/neorg/commit/db9ed0b98ba30e2b783ea9da0fddda4cf6b2a47e))
* **metagen:** use `norg_version` ([a5c2553](https://github.com/nvim-neorg/neorg/commit/a5c25531de2790133310ad874fcbbb976d082c78))
* neovim 0.9 vim.treesitter.parse_query deprecation ([#784](https://github.com/nvim-neorg/neorg/issues/784)) ([f4a9759](https://github.com/nvim-neorg/neorg/commit/f4a9759e53fadaece9d93118a0471ddffd05d394))
* **qol.todo_item:** `&lt;C-space&gt;` would not create a new TODO item with ([fc45beb](https://github.com/nvim-neorg/neorg/commit/fc45bebde0fc9811ca4e770e2ba29c791035c885))
* **qol.todo_items:** `&lt;C-space&gt;` would not respect the `create_todo_items` option ([e764b92](https://github.com/nvim-neorg/neorg/commit/e764b92065ddd6bc206aaefd92837be8d0bd8419))
* **qol.todo_items:** TODO attributes would be erroneously assigned multiple times ([1303097](https://github.com/nvim-neorg/neorg/commit/13030974acee5a49dd02c51bedeac104b4f33cb7))
* **summary:** appropriately indent nested entries ([b725a58](https://github.com/nvim-neorg/neorg/commit/b725a58f25525efc1c39a13a09e6cec0c1c0ba4d))
* **version_in_code.yml:** perform checkout in the current directory ([3d7ad5a](https://github.com/nvim-neorg/neorg/commit/3d7ad5aa4b1277ea0f3ebb93ea79179eda5f6e27))
* **version_in_code.yml:** use `fetch-depth` of `0` ([2e8fa52](https://github.com/nvim-neorg/neorg/commit/2e8fa524d2cc73002378875970048d70ae70cc0b))


### Performance Improvements

* **concealer:** don't rerender the whole file on every single BufEnter ([7419cbb](https://github.com/nvim-neorg/neorg/commit/7419cbb7262200dd94df9d398ee1e7f5b9503a50))


### Miscellaneous Chores

* **docgen:** wipe whole wiki on every reparse ([09cb3e6](https://github.com/nvim-neorg/neorg/commit/09cb3e62022ff0f93965800a728ed698db540240))


### ref

* **Makefile:** remove `install_pre_commit` target ([9a497f5](https://github.com/nvim-neorg/neorg/commit/9a497f5e8195e5b974d520f937a946cb8819f320))
* move `core.norg.dirman.summary` -&gt; `core.summary` ([254b6a6](https://github.com/nvim-neorg/neorg/commit/254b6a60b6c9f845400d2bcb0728ee7f38823781))
* **summary:** refactor of the `core.norg.dirman.summary` module ([a2fe3ee](https://github.com/nvim-neorg/neorg/commit/a2fe3eea24c628fa15b7f854cef6c7acaf9ec3f9))


### Code Refactoring

* move all `core.norg.*` modules into `core.*` ([a5824ed](https://github.com/nvim-neorg/neorg/commit/a5824edf6893b8602e560ed7675c0d4174e263e4))

## [2.0.1](https://github.com/nvim-neorg/neorg/compare/v2.0.0...v2.0.1) (2023-02-02)


### Bug Fixes

* completion for TODO items ([#711](https://github.com/nvim-neorg/neorg/issues/711)) ([9184027](https://github.com/nvim-neorg/neorg/commit/91840274112f1286ff5f4063ac6f515683b6dc67))
* **core.norg.journal:** add proper error handling for `vim.loop.fs_scandir` ([4a9a5fe](https://github.com/nvim-neorg/neorg/commit/4a9a5fe13cd454692fc4db0b27783cd005e6be56))
* **treesitter:** don't constantly log errors about erroneous document syntax trees ([9f8b0a1](https://github.com/nvim-neorg/neorg/commit/9f8b0a1759d883fae901579ea83b3ffbfc81a53b))

## [2.0.0](https://github.com/nvim-neorg/neorg/compare/v1.1.1...v2.0.0) (2023-01-06)


### ⚠ BREAKING CHANGES

* **core.norg.qol.toc:** rewrite the table of contents implementation

### Features

* **core.export:** add `NeorgExportComplete` user autocommand ([8b10e61](https://github.com/nvim-neorg/neorg/commit/8b10e61d2f2c5e626849f9a6f8cb4399c28a1a47))
* **core.norg.qol.toc:** add multiple buffer handling logic ([467e311](https://github.com/nvim-neorg/neorg/commit/467e3113c32b8b9f1950a9425aa7b74c13cd88b8))
* **core.norg.qol.toc:** implement `qflist` generation option ([77c5149](https://github.com/nvim-neorg/neorg/commit/77c514970a9d4648b05b2334a060263666f588e2))
* **treesitter:** add `execute_query` function ([310ebaa](https://github.com/nvim-neorg/neorg/commit/310ebaaef538dfd41d02a2903663be05fd38834b))


### Bug Fixes

* **core.ui:** do not modify the user's `scrolloffset` ([bd2e58c](https://github.com/nvim-neorg/neorg/commit/bd2e58cf6f9d42527aa2b692fb187eafa82bd91e))


### Performance Improvements

* further optimize `toc` infirm tag grabber ([5e8d059](https://github.com/nvim-neorg/neorg/commit/5e8d05968e04f7945576d50a6b1576cc722f96fc))
* optimize the `toc` infirm tag grabber code ([a41bd4a](https://github.com/nvim-neorg/neorg/commit/a41bd4a92afefb7e2630b821b59f7707a054baac))


### ref

* **core.norg.qol.toc:** rewrite the table of contents implementation ([c0104fb](https://github.com/nvim-neorg/neorg/commit/c0104fb9faed3b3213e4e275a55a522a299a2d0e))

## [1.1.1](https://github.com/nvim-neorg/neorg/compare/v1.1.0...v1.1.1) (2023-01-05)


### Bug Fixes

* **core.export:** incorrect exporting of code blocks with no parameters ([#701](https://github.com/nvim-neorg/neorg/issues/701)) ([0922815](https://github.com/nvim-neorg/neorg/commit/0922815837a374bd0b2a3cf0477b54e6668e133d))

## [1.1.0](https://github.com/nvim-neorg/neorg/compare/v1.0.1...v1.1.0) (2023-01-05)


### Features

* keep checkboxes with `core.itero` ([#663](https://github.com/nvim-neorg/neorg/issues/663)) ([00532bd](https://github.com/nvim-neorg/neorg/commit/00532bd997d2aef0384ed8f11500d33d229a7e53))


### Bug Fixes

* **core.export.markdown:** incorrectly exported code blocks ([dd2750c](https://github.com/nvim-neorg/neorg/commit/dd2750c0e4d847b67a6ead79ff5043e671cac8bd))
* **folds:** correctly fold document metadata ([adc000a](https://github.com/nvim-neorg/neorg/commit/adc000aadd41e68e4de8a2d1bb90b2e910ffef1b))

## [1.0.1](https://github.com/nvim-neorg/neorg/compare/1.0.0...v1.0.1) (2022-12-23)


### Bug Fixes

* **core.looking-glass:** buffer being closed for no reason after leaving buffer ([828a37f](https://github.com/nvim-neorg/neorg/commit/828a37fe1f008dbfd70cd7fc0f7ba9d0bc75da2a))
* do not run tests for nightly/neorg-main, as GTD is no longer existent ([37f1f9a](https://github.com/nvim-neorg/neorg/commit/37f1f9a44ba65603b5992fc36761c61d921fab78))
