import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json.{ string, int }
import gleam/int
import gleam/iterator
import gleam/list
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData}
import simplifile.{
    append,
    create_directory,
    create_file,
    delete,
    read,
    read_bits,
    verify_is_directory,
    verify_is_file,
    write,
}
import gtodo/database.{type Item}

const db_name = "todos.sqlite3"

pub fn main() {
    let assert Ok(_) = database.connect(db_name, database.create_schema)

    let _ = verify_tmp_storage()

    let not_found =
        response.new(404)
        |> response.set_body(mist.Bytes(bytes_builder.new()))

    let assert Ok(_) =
        fn(req: Request(Connection)) -> Response(ResponseData) {
            case request.path_segments(req) {
                ["create"] -> create(req)
                ["read_all"] -> read_all(req)
                ["clear"] -> clear(req)
                ["list"] -> list(req)
                ["new"] -> new(req)
                ["ping"] -> ping(req)
                ["remove", id] -> remove(req, id)
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

    let body_bytes = result.lazy_unwrap(body_result, fn() { <<0>> })
    let body_string = result.lazy_unwrap(bit_array.to_string(body_bytes), fn() { "" })

    use conn <- database.connect(db_name)
    let _ = database.create_item(body_string, conn)

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
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

// Annihilate everyhing below this line when we are done banging our heads against the wall
fn ping(_req: Request(Connection)) -> Response(ResponseData) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_string("Pong!")))
    |> response.set_header("content-type", "text/plain")
}

fn clear(_req: Request(Connection)) -> Response(ResponseData) {
    let _ = delete(file_or_dir_at: filepath())

    response.new(204)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
}

fn list(_req: Request(Connection)) -> Response(ResponseData) {
    let content = result.lazy_unwrap(read(filepath()), fn() { "" })

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_string(content)))
    |> response.set_header("content-type", "text/plain")
}

fn new(req: Request(Connection)) -> Response(ResponseData) {
    let body_result = mist.read_body(req, 1024 * 1024 * 10)
    |> result.map(fn(r) {
        r.body
    })

    let body_bytes = result.lazy_unwrap(body_result, fn() { <<0>> })
    let body_string = result.lazy_unwrap(bit_array.to_string(body_bytes), fn() { "" })

    let item = body_string <> "\n"
    let assert Ok(_) =
        item
        |> append(to: filepath())

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
}

fn remove(_req: Request(Connection), id: String) -> Response(ResponseData) {
    let row = result.lazy_unwrap(int.parse(id), fn() { 0 })

    let bits = result.lazy_unwrap(read_bits(filepath()), fn() { <<0>> })
    let content = result.lazy_unwrap(bit_array.to_string(bits), fn() { "" })

    let reduced_list = iterator.from_list(string.split(content, on: "\n"))
    |> iterator.index
    |> iterator.filter(fn(x) { x.1 != row })
    |> iterator.flat_map(fn(x) { iterator.from_list([x.0]) })
    |> iterator.to_list

    let assert Ok(_) =
        string.join(reduced_list, "\n")
        |> write(to: filepath())

    response.new(204)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
}

fn tmp_dir() -> String {
    "./tmp"
}

fn filepath() -> String {
    tmp_dir() <> "/todo.txt"
}

fn verify_tmp_storage() {
    let _ = create_directory(tmp_dir())
    let assert Ok(True) = verify_is_directory(tmp_dir())

    let _ = create_file(filepath())
    let assert Ok(True) = verify_is_file(filepath())
}
