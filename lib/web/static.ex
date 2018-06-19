defmodule River.Static do
    use Plug.Builder

    plug Plug.Static, at: "/", from: {:river, "priv/static"}
end