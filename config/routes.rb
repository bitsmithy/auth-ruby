# frozen_string_literal: true

Bitsmithy::Auth::Engine.routes.draw do
  get "/sign_in" => "sessions#new", as: :sign_in
  post "/send_code" => "sessions#create", as: :send_code
  get "/code" => "sessions#edit", as: :code
  post "/verify" => "sessions#update", as: :verify
  delete "/sign_out" => "sessions#destroy", as: :sign_out
end
