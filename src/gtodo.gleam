import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json.{ int }
import gleam/int
import gleam/list
import gleam/result
import mist.{type Connection, type ResponseData}
import gtodo/database.{type Item}

const db_name = "todos.sqlite3"

pub fn main() {
    let assert Ok(_) = database.connect(db_name, database.create_schema)

    let not_found =
        response.new(404)
        |> response.set_body(mist.Bytes(bytes_builder.new()))

    let assert Ok(_) =
        fn(req: Request(Connection)) -> Response(ResponseData) {
            case request.path_segments(req) {
                ["create"] -> create(req)
                ["read", item_id] -> read(req, item_id)
                ["read_all"] -> read_all(req)
                ["update", item_id] -> update(req, item_id)
                ["delete", item_id] -> delete(req, item_id)
                _ -> not_found
            }
        }
        |> mist.new
        |> mist.port(3000)
        |> mist.start_http

    process.sleep_forever()
}

fn create(req: Request(Connection)) -> Response(ResponseData) {
    let body_result = mist.read_body(req, 1024 * 1024 * 10)
    |> result.map(fn(r) {
        r.body
    })

    let assert Ok(body_bytes) = body_result
    let assert Ok(content) = bit_array.to_string(body_bytes)

    use conn <- database.connect(db_name)
    let id = database.create_item(content, conn)

    let assert Ok(id) = id

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_string(int.to_string(id))))
    |> response.set_header("content-type", "text/plain")
}

fn read(_req: Request(Connection), item_id: String) -> Response(ResponseData) {
    use conn <- database.connect(db_name)
    let item = database.read_item(item_id, conn)

    let assert Ok(item) = item

    let item_json = item_to_json(item)
    |> json.to_string()

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_string(item_json)))
    |> response.set_header("content-type", "text/plain")
}

fn read_all(_req: Request(Connection)) -> Response(ResponseData) {
    use conn <- database.connect(db_name)
    let items = database.read_items(conn)

    let items_json = items_to_json(items)
    |> json.to_string()

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_string(items_json)))
    |> response.set_header("content-type", "text/plain")
}

fn update(req: Request(Connection), item_id: String) -> Response(ResponseData) {
    let body_result = mist.read_body(req, 1024 * 1024 * 10)
    |> result.map(fn(r) {
        r.body
    })

    let assert Ok(body_bytes) = body_result
    let assert Ok(content) = bit_array.to_string(body_bytes)

    use conn <- database.connect(db_name)
    let item = database.update_item(item_id, content, conn)

    let assert Ok(item) = item

    let item_json = item_to_json(item)
    |> json.to_string()

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_string(item_json)))
    |> response.set_header("content-type", "text/plain")
}

fn delete(_req: Request(Connection), item_id: String) -> Response(ResponseData) {
    use conn <- database.connect(db_name)
    let _ = database.delete_item(item_id, conn)

    response.new(204)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
}


fn item_to_json(item: Item) -> json.Json {
    json.object([
        #("id", json.int(item.id)),
        #("content", json.string(item.content)),
    ])
}

fn items_to_json(items: List(Item)) -> json.Json {
    let items_json = list.map(items, fn(x) { item_to_json(x)})
    json.array(items_json, of: fn(j) { j })
}
