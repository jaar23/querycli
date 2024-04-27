import db_connector/db_sqlite


type
  SqlResult*[O, E] = tuple[ok: O, error: E]

  SelectResult* = object
    header*: seq[string]
    data*: seq[Row]


proc select*(db: DbConn, stmt: string): SqlResult[SelectResult, string] =
  try:
    var selectResult = SelectResult(
      header: newSeq[string](),
      data: newSeq[Row]()
    )
    var columns: DbColumns
    for row in db.instantRows(columns, sql stmt):
      var data = newSeq[string]()
      for i in 0 ..< row.len:
        data.add(row[i])
      selectResult.data.add(data)
    
    for col in columns:
      selectResult.header.add(col.name)
    
    result.ok = selectResult
  except:
    result.error = ""


proc execute*(db: DbConn, stmt: string): SqlResult[int, string] =
  try:
    let affected = db.execAffectedRows(sql stmt)
    result.ok = affected
  except:
    result.error = getCurrentExceptionMsg()


proc create*(db: DbConn, stmt: string): SqlResult[bool, string] =
  try:
    db.exec(sql stmt)
    result.ok = true
  except:
    result.ok = false
    result.error = getCurrentExceptionMsg()


proc listTable*(db: DbConn): SqlResult[seq[string], string] =
  let stmt = "SELECT tbl_name FROM sqlite_master where type = 'table'"
  try:
    let rows = db.getAllRows(sql stmt)
    result.ok = newSeq[string]()
    for row in rows:
      for col in row:
        result.ok.add(col)
  except:
    result.error = getCurrentExceptionMsg()


# get table columns
# PRAGMA table_info(tb_rates);
