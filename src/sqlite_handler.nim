import db_connector/db_sqlite
import strutils
#from terminal import ansiResetCode, ansiBackgroundColorCode, ansiForegroundColorCode
#import colors

type
  SqlResult*[O, E] = tuple[ok: O, error: E]

  SelectResult* = object
    header*: seq[string]
    data*: seq[Row]
  
  SqliteDbType* = enum
    Text, Numeric, Integer, Real, Blob, Unknown

  SqliteDbColumn* = object
    tableName*: string
    cid*: int
    name*: string
    typ*: SqliteDbType
    notNull*: bool
    defaulValue*: string
    primaryKey*: bool

  SqliteTable* = object
    name*: string
    columns*: seq[SqliteDbColumn]


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


proc listTableColumns*(db: DbConn, tableName: string): SqlResult[seq[SqliteDbColumn], string] =
  let stmt = "PRAGMA table_info(" & tableName & ")"
  try:
    var dbcolumns = newSeq[SQliteDbColumn]()
    let rows = db.getAllRows(sql stmt)
    for r in rows:
      let dbcol = SqliteDbColumn(
        tableName: tableName,
        cid: r[0].parseInt(),
        name: r[1],
        typ: 
          if r[2].startsWith("TEXT"): Text
          elif r[2].startsWith("INTEGER"): Integer
          elif r[2].startsWith("NUMERIC"): Numeric
          elif r[2].startsWith("REAL"): Real
          elif r[2].startsWith("BLOB"): Blob
          else: Unknown,
        notNull: 
          if r[3] == "true": true
          elif r[3] == "1": true
          else: false,
        defaulValue: r[4],
        primaryKey: 
          if r[5] == "true": true
          elif r[5] == "1": true
          else: false
      )
      dbcolumns.add(dbcol)
    result.ok = dbcolumns
  except:
    result.error = getCurrentExceptionMsg()


# proc tbColor*(table: string): string =
#   let text = ansiBackgroundColorCode(colBlue) & ansiForegroundColorCode(colWhite) &
#     table & ansiResetCode
#   return text
#
# proc colColor*(column: string): string =
#   let text = ansiBackgroundColorCode(colLightYellow) & ansiForegroundColorCode(colBlack) &
#     column & ansiResetCode
#   return text
#
#
