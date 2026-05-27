# frozen_string_literal: true

module Bitsmithy
  module Auth
    Identity = Data.define(
      :phone, :issued_at, :expires_at
    )
  end
end
