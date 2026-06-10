# frozen_string_literal: true

class TestController < ApplicationController
  include Bitsmithy::Auth::Controller

  before_action :require_authentication!

  def index
    render plain: "OK"
  end
end
