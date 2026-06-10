# frozen_string_literal: true

Rails.application.routes.draw do
  mount Bitsmithy::Auth::Engine => "/auth"
  get "/test" => "test#index"
end
