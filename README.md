# ElixirCsvStream
Elixir CSV data format streaming using [send_chunked/2](https://hexdocs.pm/plug/Plug.Conn.html#send_chunked/2) and DB seeding with 1e6 rows.

## Requirements
* PostgreSQL 9.5 or newer
* Elixir 1.5 or newer

## How to start
* cd `elixir_csv_stream`
* `iex -S mix`

## Elixir program flow
1. opens a connection to the database `foo`
2. fills the table `source` with 1 million rows where:
  * column a contains the numbers from 1 to 1e6
  * column b has a % 3
  * column c has a % 5
3. opens a connection to the database `bar`
4. copies the data from table `source` in `foo` to table `dest` in `bar` using postgresql copy command (without saving data into a file)
Then:
5. starts a web server that has two endpoints: `./dbs/foo/tables/source` and `./dbs/bar/tables/dest`
  * upon a `GET` request to either of the two it must respond with contents of a corresponding table serialized as CSV and using HTTP chunked encoding. Data must be streamed from the database upon a request, not stored in a file or cached in memory
