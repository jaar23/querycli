# Package

version       = "0.1.0"
author        = "jaar23"
description   = "tui enabled sql query tool"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["querycli"]


# Dependencies

requires "nim >= 2.0.2"
requires "tui_widget >= 0.1.0"
requires "db_connector >= 0.1.0"
