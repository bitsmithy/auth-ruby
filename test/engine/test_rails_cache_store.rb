# frozen_string_literal: true

require_relative "../engine_helper"

class RailsCacheStoreTest < ActiveSupport::TestCase
  setup do
    @store = Bitsmithy::Auth::Stores::RailsCacheStore.new(Rails.cache)
  end

  test "increment returns 1 on first call" do
    assert_equal 1, @store.increment("counter:a", 60)
  end

  test "increment returns cumulative count on subsequent calls" do
    @store.increment("counter:b", 60)
    @store.increment("counter:b", 60)

    assert_equal 3, @store.increment("counter:b", 60)
  end

  test "different keys are independent" do
    @store.increment("counter:c", 60)
    @store.increment("counter:c", 60)

    assert_equal 1, @store.increment("counter:d", 60)
  end
end
