# gtodo

## Run and curl.
- Create `curl -X POST http://localhost:3000/create -d "content of your item"`
- Read `curl http://localhost:3000/read/1`
- Read All `curl http://localhost:3000/read_all`
- Update `curl -X PUT http://localhost:3000/update/1 -d "updated content"`
- Delete `curl http://localhost:3000/delete/1`

## To add
- Logging
- Only accept correct request method for each endpoint
