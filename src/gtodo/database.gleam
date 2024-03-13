import gleam/dynamic
import gleam/io
import gleam/list
import sqlight

pub type Todo {
    Todo(id: Int, item: String)
}

pub type Conn = sqlight.Connection

pub fn connect(name: String, f: fn(sqlight.Connection) -> a) -> a {
    use db <- sqlight.with_connection(name)
    let assert Ok(_) = sqlight.exec("pragma foreign_keys = on;", db)
    f(db)
}

pub fn create_schema(db: sqlight.Connection) -> Result(Nil, sqlight.Error) {
    sqlight.exec("create table todos (id int, item text);", db)
}

pub fn test_db(db: sqlight.Connection) {
    let assert Ok(_) = sqlight.exec("insert into todos (id, item) values (1337, 'Test');", db)
    let assert Ok(res) = sqlight.query(
        "select id, item from todos where id = ?",
        on: db,
        with: [sqlight.int(1337)],
        expecting: todo_decoder(),
    )

    res
    |> list.map(fn(x) { x })
    |> io.debug

    sqlight.exec("drop table todos;", db)
}

fn todo_decoder() -> dynamic.Decoder(Todo) {
    dynamic.decode2(
        Todo,
        dynamic.element(0, dynamic.int),
        dynamic.element(1, dynamic.string),
    )
}
