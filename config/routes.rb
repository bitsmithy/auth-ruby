# frozen_string_literal: true

Bitsmithy::Auth::Engine.routes.draw do
  get "/passkeys/authentication" => "passkey_authentications#show", as: :passkey_authentication
  post "/passkeys/authentication" => "passkey_authentications#create"
  get "/passkeys/registration" => "passkey_registrations#show", as: :passkey_registration
  post "/passkeys/registration" => "passkey_registrations#create"
  get "/apple" => "federated_authentications#apple", as: :apple_authentication
  post "/apple/callback" => "federated_authentications#apple_callback", as: :apple_callback
  get "/google" => "federated_authentications#google", as: :google_authentication
  get "/google/callback" => "federated_authentications#google_callback", as: :google_callback
  get "/email_magic_links/new" => "email_magic_links#new", as: :new_email_magic_link
  post "/email_magic_links" => "email_magic_links#create", as: :email_magic_links
  get "/email_magic_links/sent" => "email_magic_links#sent", as: :email_magic_link_sent
  get "/email" => "email_magic_links#exchange", as: :email_magic_link_exchange
  post "/email_magic_links/verify" => "email_magic_links#verify", as: :verify_email_magic_link
  get "/sign_in" => "federated_authentications#new", as: :sign_in
end
