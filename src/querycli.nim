import tui_widget, illwill, std/enumerate, strutils
import db_connector/db_sqlite
import sqlite_handler

let db = open("rates.db", "", "", "")
 
var dbTablePanel = newListView(id="tbl")
dbTablePanel.title = " Tables "
dbTablePanel.statusbar = false
dbTablePanel.selectionStyle = HighlightArrow

var dbTables = newSeq[ListRow]()
for tbl in listTable(db).ok:
  dbTables.add(newListRow(0, tbl, tbl, bgColor=bgBlue))

dbTablePanel.rows = dbTables


var resultTbl = newTable(id="result")
resultTbl.statusbar = true
resultTbl.title = ""
resultTbl.enableHelp = false

var queryPanel = newTextArea(id="qry")
queryPanel.statusbar = false
queryPanel.title = " SQL Editor "

var runBtn = newButton(id="run")
runBtn.label = "RUN"

var tuiapp = newTerminalApp(title="querycli")

proc emptyRecord(table: Table, args: varargs[string]) =
  table.tb.write(table.x1, table.y1 + 2,
                bgNone, fgWhite, center("no records found", table.x2 - table.x1), 
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
      let row = if sqlresult.ok > 0: @[$sqlresult.ok]  else: @[sqlresult.error]
      resultTbl.loadFromSeq(@[row])
    elif stmt.toLower().startsWith("create") or 
      stmt.toLower().startsWith("alter"):
      let sqlresult = create(db, stmt)
      var header = newTableRow()
      header.columns(@["result"])
      resultTbl.header = header
      let row = if sqlresult.ok: @["true"]  else: @[sqlresult.error]
      resultTbl.loadFromSeq(@[row])
    else:
      let sqlresult = select(db, stmt)
      var header = newTableRow()
      var rows = newSeq[seq[string]]()
      
      for i, row in enumerate(sqlresult.ok.data):
        var sqlrow = newSeq[string]()
        for col in row.items:
          sqlrow.add(col)
        rows.add(sqlrow)
      for col in sqlresult.ok.header:
        header.addColumn(newTableColumn(col.len, 1, col, bgColor=bgWhite, fgColor=fgCyan))
      resultTbl.title = " " & stmt & " "
      resultTbl.header = header
      resultTbl.loadFromSeq(rows)
   
 
proc runQuery(btn: Button, args: varargs[string]) =
  queryPanel.call("query")


proc sampleQuery(lv: ListView, args: varargs[string]) =
  let table = lv.selected.value
  let stmt = "SELECT * FROM " & table
  queryPanel.value = stmt

 
when isMainModule:
  resultTbl.on("empty", emptyRecord)
  dbTablePanel.on("enter", sampleQuery)
  queryPanel.on(Key.F5, execQuery)
  queryPanel.on("query", execQuery)
  runBtn.on("enter", runQuery)

  tuiapp.addWidget(dbTablePanel, 0.2, 1.0)
  tuiapp.addWidget(resultTbl, 0.8, 0.70)
  tuiapp.addWidget(queryPanel, 0.8, 0.20, toConsoleWidth(0.2) + 1, 0, 0, 0)
  tuiapp.addWidget(runBtn, 0.8, 0.1, toConsoleWidth(0.2) + 1, 0, 0, 0)

  tuiapp.run() 
  db.close()
