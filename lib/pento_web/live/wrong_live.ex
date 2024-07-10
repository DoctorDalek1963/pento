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
    <%= if @has_won do %>
      <.link navigate={~p"/guess"}><strong>Reset</strong></.link>
    <% else %>
      <h2>
        <%= for n <- 1..10 do %>
          <.link href="#" phx-click="guess" phx-value-number={n}>
            <%= n %>
          </.link>
        <% end %>
      </h2>
    <% end %>
    """
  end

  def handle_event("guess", %{"number" => number}, socket) do
    if number == to_string(socket.assigns.target) do
      message = "Your guess: #{number}. Correct! You win!"
      score = socket.assigns.score + 1

      {:noreply, assign(socket, score: score, message: message, has_won: true)}
    else
      message = "Your guess: #{number}. Wrong. Guess again:"
      score = socket.assigns.score - 1

      {:noreply, assign(socket, score: score, message: message)}
    end
  end
end
