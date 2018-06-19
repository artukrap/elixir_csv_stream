defmodule River.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    seed_db(10_000)

    children = [
      Plug.Adapters.Cowboy.child_spec(
        scheme: :http,
        plug: River.Router,
        options: [port: Application.get_env(:river, :port)]
      )
    ]

    Logger.info("Listening on port #{Application.get_env(:river, :port)}")

    opts = [strategy: :one_for_one, name: River.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp seed_db(batch_size) do
    {:ok, foo_pid} =
      Postgrex.start_link(
        hostname: "localhost",
        username: "postgres",
        password: "",
        database: "foo"
      )

    Postgrex.query!(
      foo_pid,
      "CREATE TABLE IF NOT EXISTS source ( a bigint, b bigint, c bigint);",
      []
    )

    Postgrex.query!(
      foo_pid,
      "TRUNCATE source;",
      []
    )

    # TODO: move inital db population from CSV file with `COPY`
    Enum.reduce(1..1_000_000, [], fn number, acc ->
      insert_value =
        [
          number,
          Integer.mod(number, 3),
          Integer.mod(number, 5)
        ]
        |> Enum.join(",")

      # If batch size reached, INSERT INTO db
      if Enum.count(acc) == batch_size do
        acc
        |> Enum.join(",")
        |> insert_values(foo_pid, "source")

        ["(#{insert_value})"]
      else
        acc ++ ["(#{insert_value})"]
      end
    end)
    |> Enum.join(",")
    |> insert_values(foo_pid, "source")

    {:ok, bar_pid} =
      Postgrex.start_link(
        hostname: "localhost",
        username: "postgres",
        password: "",
        database: "bar"
      )

    Postgrex.query!(
      bar_pid,
      "CREATE TABLE IF NOT EXISTS dest ( a bigint, b bigint, c bigint);",
      []
    )

    Postgrex.query!(
      bar_pid,
      "TRUNCATE dest;",
      []
    )

    # COPY data to `dest` table
    source_data =
      Postgrex.query!(
        foo_pid,
        "copy source to stdout with delimiter ',';",
        []
      )

    Enum.reduce(source_data.rows, [], fn row, acc ->
      # If batch size reached, INSERT INTO db
      if Enum.count(acc) == batch_size do
        acc
        |> Enum.join(",")
        |> insert_values(bar_pid, "dest")

        ["(#{row})"]
      else
        acc ++ ["(#{row})"]
      end
    end)
    |> Enum.join(",")
    |> insert_values(bar_pid, "dest")
  end

  defp insert_values(values, pid, table) do
    Postgrex.query!(pid, "INSERT INTO #{table} VALUES #{values};", [])
  end
end
