defmodule PentoWeb.WrongLive do
  use PentoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       score: 0,
       message: "Make a guess:",
       target: :rand.uniform(10),
       has_won: false
     )}
  end

  def render(assigns) do
    ~H"""
    <h1>Your score: <%= @score %></h1>
    <h2><%= @message %></h2>
    <h2 class="my-2">
      <%= if @has_won do %>
        <.link navigate={~p"/guess"}><strong>Reset</strong></.link>
      <% else %>
        <%= for n <- 1..10 do %>
          <.link href="#" phx-click="guess" phx-value-number={n} class="mx-2">
            <%= n %>
          </.link>
        <% end %>
      <% end %>
    </h2>
    """
  end

  def handle_event(
        "guess",
        %{"number" => number},
        %Phoenix.LiveView.Socket{assigns: %{score: score, target: target}} = socket
      ) do
    if number == to_string(target) do
      {:noreply,
       assign(socket,
         score: score + 1,
         message: "Your guess: #{number}. Correct! You win!",
         has_won: true
       )}
    else
      {:noreply,
       assign(socket,
         score: score - 1,
         message: "Your guess: #{number}. Wrong. Guess again:"
       )}
    end
  end
end
