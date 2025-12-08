defmodule FosBjjWeb.PageController do
  use FosBjjWeb, :controller

  def home(conn, _params) do
    positions =
      FosBjj.JiuJitsu.Position
      |> Ash.Query.for_read(:read)
      |> Ash.read!()

    render(conn, :home, positions: positions)
  end
end
