# frozen_string_literal: true

require_relative "../../test_helper"

class TestTestingSupport < Minitest::Test
  def test_builds_deterministic_email_evidence
    evidence = Bitsmithy::Auth::Testing.authentication_evidence(
      :email,
      environment: :test,
      email: "Alex@Example.com",
      authenticated_at: Time.utc(2026, 8, 28, 12, 0, 0)
    )

    assert_equal :email, evidence.sign_in_method
    assert_equal "alex@example.com", evidence.email
  end

  def test_refuses_to_build_evidence_in_production
    assert_raises(Bitsmithy::Auth::ConfigurationError) do
      Bitsmithy::Auth::Testing.authentication_evidence(
        :email,
        environment: :production,
        email: "alex@example.com"
      )
    end
  end
end
