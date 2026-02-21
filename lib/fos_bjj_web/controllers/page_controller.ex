defmodule FosBjjWeb.PageController do
  use FosBjjWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def mission(conn, _params) do
    render(conn, :mission)
  end
end
