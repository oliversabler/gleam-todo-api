import gleam/dynamic
import gleam/int
import gleam/result
import sqlight

pub type Item {
  Item(id: Int, content: String)
}

pub type DbError {
  BadRequest
  ContentRequired
  NotFound
  SqlightError(sqlight.Error)
}

pub fn connect(name: String, f: fn(sqlight.Connection) -> a) -> a {
  use db <- sqlight.with_connection(name)
  let assert Ok(_) = sqlight.exec("pragma foreign_keys = on;", db)
  f(db)
}

pub fn create_schema(db: sqlight.Connection) -> Result(Nil, DbError) {
  sqlight.exec(
    "create table if not exists items (
        id integer primary key autoincrement not null,
        content text
    );",
    db,
  )
  |> result.map_error(SqlightError)
}

pub fn create_item(
  content: String,
  db: sqlight.Connection,
) -> Result(Int, DbError) {
  let query = "insert into items (content) values (?) returning id"

  use rows <- result.then(
    sqlight.query(
      query,
      on: db,
      with: [sqlight.text(content)],
      expecting: dynamic.element(0, dynamic.int),
    )
    |> result.map_error(fn(error) {
      case error.code, error.message {
        sqlight.ConstraintCheck, "CHECK constraint failed: empty_content" ->
          ContentRequired
        _, _ -> BadRequest
      }
    }),
  )

  let assert [id] = rows
  Ok(id)
}

pub fn read_item(
  item_id: String,
  db: sqlight.Connection,
) -> Result(Item, DbError) {
  let query = "select id, content from items where id = ?"

  let id = result.lazy_unwrap(int.parse(item_id), fn() { 0 })

  let assert Ok(rows) =
    sqlight.query(
      query,
      on: db,
      with: [sqlight.int(id)],
      expecting: result_parser(),
    )

  case rows {
    [item] -> Ok(item)
    _ -> Error(NotFound)
  }
}

pub fn read_items(db: sqlight.Connection) -> List(Item) {
  let query = "select id, content from items"

  let assert Ok(rows) =
    sqlight.query(query, on: db, with: [], expecting: result_parser())

  rows
}

pub fn update_item(
  item_id: String,
  content: String,
  db: sqlight.Connection,
) -> Result(Item, DbError) {
  let query =
    "update items set content = ?1 where id = ?2 returning id, content"

  let id = result.lazy_unwrap(int.parse(item_id), fn() { 0 })

  let assert Ok(rows) =
    sqlight.query(
      query,
      on: db,
      with: [sqlight.text(content), sqlight.int(id)],
      expecting: result_parser(),
    )

  case rows {
    [item] -> Ok(item)
    _ -> Error(NotFound)
  }
}

pub fn delete_item(item_id: String, db: sqlight.Connection) -> Nil {
  let query = "delete from items where id = ?"

  let id = result.lazy_unwrap(int.parse(item_id), fn() { 0 })

  let assert Ok(_) =
    sqlight.query(query, on: db, with: [sqlight.int(id)], expecting: Ok)

  Nil
}

fn result_parser() -> dynamic.Decoder(Item) {
  dynamic.decode2(
    Item,
    dynamic.element(0, dynamic.int),
    dynamic.element(1, dynamic.string),
  )
}
