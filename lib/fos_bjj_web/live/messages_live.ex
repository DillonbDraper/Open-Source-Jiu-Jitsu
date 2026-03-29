defmodule FosBjjWeb.MessagesLive do
  use FosBjjWeb, :live_view

  alias FosBjjWeb.Components.ReceivedMessagesTable
  alias FosBjjWeb.Components.SentMessagesTable

  on_mount({FosBjjWeb.LiveUserAuth, :live_user_required})

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Message Center")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} full_width current_user={assigns[:current_user]} socket={@socket}>
      <div class="space-y-6">
        <header class="flex flex-wrap items-start justify-between gap-4">
          <div class="space-y-2">
            <.h1 class="text-3xl font-extrabold tracking-tight text-base-content">Message Center</.h1>
            <.p class="text-sm text-base-content/70">
              View received and sent messages in one place.
            </.p>
          </div>

          <.link id="message-center-back-link" navigate={~p"/database"} class="btn btn-ghost">
            ← Back To Database
          </.link>
        </header>

        <.tabs
          id="message-center-tabs"
          variant="nav_pills"
          color="primary"
          rounded="large"
          size="medium"
          padding="small"
          gap="small"
          content_padding="none"
          class="bg-base-200/70 rounded-xl p-1"
        >
          <:tab active>Received Messages</:tab>
          <:tab :if={@current_user.role_name in ["coach", "contributor", "admin"]}>
            Sent Messages
          </:tab>

          <:panel class="pt-6">
            <.live_component
              module={ReceivedMessagesTable}
              id="received-messages-table"
              current_user={@current_user}
            />
          </:panel>
          <:panel
            :if={@current_user.role_name in ["coach", "contributor", "admin"]}
            class="pt-6"
          >
            <.live_component
              module={SentMessagesTable}
              id="sent-messages-table"
              current_user={@current_user}
            />
          </:panel>
        </.tabs>
      </div>
    </Layouts.app>
    """
  end
end
