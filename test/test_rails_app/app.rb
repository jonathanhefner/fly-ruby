require 'rails'
require "active_record"
require "action_view/railtie"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_cable/engine"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"
require_relative '../../lib/fly-ruby/railtie'

ActiveSupport::Deprecation.silenced = true

# need to init app before establish connection so sqlite can place the database file under the correct project root
class TestApp < Rails::Application
end

ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "fly_ruby_test")
ActiveRecord::Base.logger = Logger.new(nil)

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
  end

  create_table :comments, force: true do |t|
    t.integer :post_id
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

class ApplicationController < ActionController::Base; end

class PostsController < ApplicationController
  def index
    Post.all.to_a
    raise "foo"
  end

  def show
    p = Post.find(params[:id])

    render plain: p.id
  end
end

class HelloController < ApplicationController
  prepend_view_path "spec/support/test_rails_app"

  def exception
    raise "An unhandled exception!"
  end

  def view
    render template: "test_template"
  end

  def world
    render :plain => "Hello World!"
  end

  def not_found
    raise ActionController::BadRequest
  end
end

def make_basic_app
  app = Class.new(TestApp) do
    def self.name
      "RailsTestApp"
    end
  end

  app.config.hosts = nil
  app.config.secret_key_base = "test"

  # Usually set for us in production.rb
  app.config.eager_load = true
  app.routes.append do
    get "/exception", :to => "hello#exception"
    get "/view", :to => "hello#view"
    get "/not_found", :to => "hello#not_found"
    get "/world", to: "hello#world"
    resources :posts, only: [:index, :show]
    root :to => "hello#world"
  end

  app.initializer :configure_release do
    Fly.configure do |config|
      config.replay_threshold_in_seconds = 5
    end
  end

  app.initialize!

  Rails.application = app
  app
end
