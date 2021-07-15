require "rack/test"
require "minitest/autorun"
require "bundler/setup"
require "climate_control"
require "minitest/around/unit"

require_relative "test_rails_app/app"

POSTGRES_HOST = ENV['DATABASE_HOST'] || 'localhost'
ENV["DATABASE_URL"] = "postgres://#{POSTGRES_HOST}:5432/fly_ruby_test"

class TestFlyRails < Minitest::Test
  include Rack::Test::Methods

  def setup
    ENV["FLY_REGION"] = "ams"
    Fly.configuration.primary_region = "ams"
    Fly.configuration.current_region = "iad"
    @app = make_basic_app
  end

  def app
    @app
  end

  def test_middleware_inserted_with_required_env_vars
    index_of_executor = @app.middleware.find_index { |m| m == ActionDispatch::Executor }
    assert_equal index_of_executor + 1, @app.middleware.find_index(Fly::RegionalDatabase)
  end

  def test_database_connection_is_overloaded
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "ams.#{POSTGRES_HOST}", config[:host]
    assert_equal 5433, config[:port]
  end

  def test_debug_headers_are_appended_to_responses
    get "/"
    assert_equal "ams", last_response.headers["Fly-Region"]
    assert_equal "ams.#{POSTGRES_HOST}", last_response.headers["Fly-Database-Host"]
  end
end

class TestBadEnv < Minitest::Test
  def setup
    Fly.configuration.primary_region = nil
  end

  def test_middleware_skipped_without_required_env_vars
    make_basic_app
    refute Rails.application.middleware.find_index(Fly::RegionalDatabase)
  end
end