# frozen_string_literal: true

class TestController < ApplicationController
  def index
    render plain: "OK"
  end

  def seed_session
    session[:stale_value] = "old"
    head :no_content
  end
end
