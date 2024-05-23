import tui_widget, illwill, std/enumerate, strutils, sequtils
import argparse, sugar, tables as systable, std/wordwrap
import db_connector/db_sqlite
import sqlite_handler
# from terminal import styleBright, styleBlink, ansiStyleCode, ansiResetCode,
#      resetAttributes

var db: DbConn
var cliopts = newParser:
  command("sqlite"):
    option("-f", "--file", help = "sqlite database file")
  command("pgsql"):
    option("-u", "--username", help = "postgresql user's username")
    option("-p", "--password", help = "postgresql user's password")
    option("-h", "--host", help = "postgresql host")
    option("-pt", "--port", help = "posgresql exposed port")
  help("{prog} is a sql query tool with tui cli.")


var args = commandLineParams()
var opts = cliopts.parse(args)
var dbobjects = systable.initTable[string, seq[SqliteDbColumn]]()

if opts.sqlite.isSome:
  let path = if opts.sqlite.get.file_opt.isSome: opts.sqlite.get.file
    else:
      echo "Please provide the databse file for connection"
      quit(0)
  db = open(path, "", "", "")
  var dbtables = listTable(db)

  for tbl in dbtables.ok:
    let dbcolumns = listTableColumns(db, tbl)
    if dbcolumns.error == "":
      dbobjects[tbl] = dbcolumns.ok

elif opts.pgsql.isSome:
  echo "not implemented"
  quit(0)
else:
  echo "please specific databse and connection options"
  quit(0)


var dbTablePanel = newListView(id = "tbl")
dbTablePanel.title = " Tables "
dbTablePanel.statusbar = false
dbTablePanel.selectionStyle = HighlightArrow

var dbTables = newSeq[ListRow]()
for tbl in listTable(db).ok:
  dbTables.add(newListRow(0, "[T] " & tbl, tbl, bgColor = bgBlue))
  for tblCol in listTableColumns(db, tbl).ok:
    dbTables.add(newListRow(0, "   [C] " & tblCol.name, tblCol.tableName,
        bgColor = bgBlue))

dbTablePanel.rows = dbTables


var resultTbl = newTable(id = "result")
resultTbl.statusbar = true
resultTbl.title = ""
resultTbl.enableHelp = false

var queryPanel = newTextArea(id = "qry")
queryPanel.statusbar = false
queryPanel.title = " SQL Editor "
queryPanel.enableAutocomplete = true
queryPanel.autocompleteTrigger = 1
queryPanel.autocompleteBgColor = bgGreen
queryPanel.autocompleteFgColor = fgWhite

var runBtn = newButton(id = "run")
runBtn.label = "RUN"

var tuiapp = newTerminalApp(title = "querycli")

proc emptyRecord(table: table_wg.Table, args: varargs[string]) =
  table.tb.write(table.x1, table.y1 + 2,
                bgNone, fgWhite, center("no records found", table.x2 -
                    table.x1),
                resetStyle)
  table.focus = false


proc execQuery(txtarea: TextArea, args: varargs[string]) =
  if txtarea.value != "":
    resultTbl.clearRows()
    let stmt = txtarea.value.strip()
    if stmt.toLower().startsWith("insert") or
      stmt.toLower().startsWith("update"):
      let sqlresult = execute(db, stmt)
      var headerRow = newTableRow()
      headerRow.columns(@["affected"])
      resultTbl.header = headerRow
      let row = if sqlresult.ok > 0: @[$sqlresult.ok] else: @[sqlresult.error]
      resultTbl.loadFromSeq(@[row])
    elif stmt.toLower().startsWith("create") or
      stmt.toLower().startsWith("alter"):
      let sqlresult = create(db, stmt)
      var header = newTableRow()
      header.columns(@["result"])
      resultTbl.header = header
      let row = if sqlresult.ok: @["true"] else: @[sqlresult.error]
      resultTbl.loadFromSeq(@[row])
    else:
      let sqlresult = select(db, stmt)
      var header = newTableRow()
      resultTbl.headerFromArray(sqlresult.ok.header, fgColor = fgBlue)
      for i, row in enumerate(sqlresult.ok.data):
        var tableRow = newTableRow()
        for i, col in enumerate(row.items):
          var text = if col.len > 50: col[0..50].escape() & ".." else: col.escape()
          text.delete(0..0)
          text.delete(text.len - 1..text.len - 1)
          var column = newTableColumn(text, col)
          column.key = sqlresult.ok.header[i]
          tableRow.addColumn(column)
        resultTbl.addRow(tableRow)
      resultTbl.title = " " & stmt & " "
      resultTbl.render()


proc autocomplete(txtarea: TextArea, args: varargs[string]) =
  let sqlClauses = ["ABORT", "ACTION", "ADD", "AFTER", "ALL", "ALTER", "ALWAYS",
                     "ANALYZE", "AND", "AS", "ASC", "ATTACH", "AUTOINCREMENT",
                     "BEFORE", "BEGIN", "BETWEEN", "BY", "CASCADE", "CASE",
                     "CAST", "CHECK", "COLLATE", "COLUMN", "COMMIT", "CONFLICT",
                     "CONSTRAINT", "CREATE", "CROSS", "CURRENT", "CURRENT_DATE",
                     "CURRENT_TIME", "CURRENT_TIMESTAMP", "DATABASE", "DEFAULT",
                     "DEFERRABLE", "DEFERRED", "DELETE", "DESC", "DETACH",
                     "DISTINCT", "DO", "DROP", "EACH", "ELSE", "END", "ESCAPE",
                     "EXCEPT",
                     "EXCLUDE", "EXCLUSIVE", "EXISTS", "EXPLAIN", "FAIL",
                     "FILTER", "FIRST",
                     "FOLLOWING", "FOR", "FOREIGN", "FROM", "FULL", "GENERATED",
                     "GLOB", "GROUP", "GROUPS", "HAVING", "IF", "IGNORE",
                     "IMMEDIATE",
                     "IN", "INDEX", "INDEXED", "INITIALLY", "INNER", "INSERT",
                     "INSTEAD",
                     "INTERSECT", "INTO", "IS", "ISNULL", "JOIN", "KEY", "LAST",
                     "LEFT", "LIKE", "LIMIT", "MATCH", "MATERIALIZED",
                     "NATURAL", "NO",
                     "NOT", "NOTHING", "NOTNULL", "NULL", "NULLS", "OF",
                     "OFFSET", "ON",
                     "OR", "ORDER", "OTHERS", "OUTER", "OVER", "PARTITION",
                     "PLAN",
                     "PRAGMA", "PRECEDING", "PRIMARY", "QUERY", "RAISE",
                     "RANGE",
                     "RECURSIVE", "REFERENCES", "REGEXP", "REINDEX", "RELEASE",
                     "RENAME",
                     "REPLACE", "RESTRICT", "RETURNING", "RIGHT", "ROLLBACK",
                     "ROW", "ROWS",
                     "SAVEPOINT", "SELECT", "SET", "TABLE", "TEMP", "TEMPORARY",
                     "THEN", "TIES", "TO", "TRANSACTION", "TRIGGER",
                     "UNBOUNDED", "UNION",
                     "UNIQUE", "UPDATE", "USING", "VACUUM", "VALUES", "VIEW",
                     "VIRTUAL", "WHEN", "WHERE", "WINDOW", "WITH", "WITHOUT"]

  let scalarFunction = ["ABS", "CHANGES", "CHAR", "COALESCE", "CONCAT", "CONCAT_WS",
                         "FORMAT", "GLOB", "HEX", "IFNULL", "IIF", "INSTR",
                         "LAST_INSERT_ROWID", "LENGTH",
                         "LIKE", "LIKELIHOOD", "LIKELY", "LOAD_EXTENSION",
                         "LOWER",
                         "LTRIM", "MAX", "MIN", "NULLIF", "OCTECT_LENGTH",
                         "PRINTF",
                         "QUOTE", "RANDOM", "RANDOMBLOB", "REPLACE", "ROUND",
                         "RTRIM", "SIGN",
                         "SOUNDEX", "SQLITE_COMPILEOPTION_GET",
                         "SQLITE_COMPILEOPTION_USED",
                         "SQLITE_OFFSET", "SQLITE_SOURCE_ID", "SQLITE_VERSION",
                         "SUBSTR",
                         "SUBSTRING", "TOTAL_CHANGES", "TRIM", "TYPEOF",
                         "UNHEX", "UNICODE", "UNLIKELY", "UPPER",
                         "ZEROBLOB"]

  let aggregateFunction = ["AVG", "COUNT", "GROUP_CONCAT", "MAX", "MIN",
      "STRING_AGG", "SUM", "TOTAL"]

  let datetimeFunction = ["DATE", "TIME", "DATETIME", "JULIANDAY", "UNIXEPOCH",
      "STRFTIME", "TIMEDIFF"]

  let currToken = args[0]
  var tokens = splitByToken(txtarea.value())
  var completionList = newSeq[Completion]()
  
  var hasTable = false
  var tableName = ""
  var populateTable = false

  for token in tokens.filter((x: WordToken) => x.token != ""):
    if token.token.toUpper() == "FROM": 
      populateTable = true
      continue
    else: continue
    if populateTable and token.token.toUpper() == "JOIN":
      populateTable = true
    else:
      populateTable = false
  if populateTable:
    for t in dbobjects.keys():
      if txtarea.value.contains(t):
        hasTable = true
        tableName = t
        break

    for t in dbobjects.keys():
      if t.toUpper().startsWith(currToken.toUpper()):
        completionList.add(Completion(icon: "[T]  ", value: t,
            description: ""))
  
  if tableName != "":
    let columns = dbobjects[tableName]
    for c in columns:
      if c.name.toUpper().startsWith(currToken.toUpper()):
        completionList.add(Completion(icon: "[C]  ", value: c.name, description: ""))

  if currToken != "":
    var aggfn = aggregateFunction.filter((x: string) => x.startsWith(
        currToken.toUpper))
    for s in aggfn:
      completionList.add(Completion(icon: "[S]", value: s, description: ""))
    
    var dtfn = datetimeFunction.filter((x: string)  => x.startsWith(currToken.toUpper))
    for s in aggfn:
      completionList.add(Completion(icon: "[S]", value: s, description: ""))

    var clauses = sqlClauses.filter((x: string) => x.startsWith(
        currToken.toUpper))
    for s in clauses:
      completionList.add(Completion(icon: "[S]", value: s, description: ""))

  txtarea.autocompleteList = completionList

proc runQuery(btn: Button, args: varargs[string]) =
  queryPanel.call("query")


proc sampleQuery(lv: ListView, args: varargs[string]) =
  let table = lv.selected.value
  let stmt = "SELECT * FROM " & table
  queryPanel.value = stmt


proc displayRow(tbl: table_wg.Table, args: varargs[string]) =
  var display = newDisplay(tbl.x1 + 2, (tbl.y2 / 6).toInt, 
                           tbl.x2 - 2, tbl.y2 - (tbl.y2 / 6).toInt, 
                           title="Row Detail", statusbar = false, 
                           bgColor=bgWhite, fgColor=fgBlack,
                           tb=tbl.tb)
  var colWitdh = 0
  for col in tbl.selected().columns():
    if col.key.len > colWitdh: colWitdh = col.key.len + 1

  for col in tbl.selected().columns():
    display.text = display.text & alignLeft(col.key, colWitdh) & "\n\n"
    var content = wrapWords(col.value, display.x2 - display.x1 - colWitdh)
    for c in content.splitLines():
      display.text = display.text & " ".repeat(colWitdh) & c & "\n"
    display.text = display.text & "-".repeat(display.width - display.x1) & "\n"
  display.illwillInit = true
  display.onControl()


when isMainModule:
  resultTbl.on("empty", emptyRecord)
  resultTbl.on("enter", displayRow)
  dbTablePanel.on("enter", sampleQuery)
  queryPanel.on(Key.F5, execQuery)
  queryPanel.on("query", execQuery)
  queryPanel.on("autocomplete", autocomplete)
  runBtn.on("enter", runQuery)

  tuiapp.addWidget(dbTablePanel, 0.2, 1.0)
  tuiapp.addWidget(resultTbl, 0.8, 0.70)
  tuiapp.addWidget(queryPanel, 0.8, 0.20, toConsoleWidth(0.2) + 1, 0, 0, 0)
  tuiapp.addWidget(runBtn, 0.8, 0.1, toConsoleWidth(0.2) + 1, 0, 0, 0)

  tuiapp.run()
  db.close()
