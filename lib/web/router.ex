defmodule River.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(River.Static)

  plug(:match)
  plug(:dispatch)

  get "/favicon.ico" do
    send_resp(conn, 200, '')
  end

  get "/" do
    send_resp(conn, 200, "Hello world")
  end

  get "/dbs/:db/tables/:table" do
    {:ok, pid} =
      Postgrex.start_link(
        hostname: "localhost",
        username: "postgres",
        password: "",
        database: conn.params["db"]
      )

    conn = send_chunked(conn, 200)

    Postgrex.transaction(pid, fn db_conn ->
      query =
        Postgrex.prepare!(
          db_conn,
          "",
          "COPY #{conn.params["table"]} TO STDOUT with delimiter ','"
        )

      stream = Postgrex.stream(db_conn, query, [])

      Enum.into(stream, [], fn %Postgrex.Result{rows: rows} ->
        {:ok, _conn} = chunk(conn, Enum.join(rows, ""))
      end)
    end)

    conn
  end
end
