require "spec_helper"
require "tmpdir"
require "generators/wibawa/install/install_generator"

RSpec.describe "Wibawa and the signed-in user", type: :request do
  let(:log) { StringIO.new }

  before do
    Wibawa::ApplicationController.wibawa_no_user_warned = false
    Wibawa::ApplicationController.logger = Logger.new(log)
  end

  after do
    Wibawa.config.current_user = :current_user
    Wibawa.config.instance_variable_set(:@authenticate, nil)
    Wibawa.config.authorization = nil
    Wibawa::ApplicationController.logger = Rails.logger
  end

  def seen_user
    seen = []
    Wibawa.config.authorization = ->(user, _action, _subject) { seen << user and true }
    get "/admin/orders"
    expect(response).to have_http_status(:ok)
    seen.uniq
  end

  it "works with no sign-in at all, and says nothing" do
    expect(seen_user).to eq([ nil ])
    expect(log.string).not_to include("Wibawa:")
  end

  it "warns once when the app signs people in but has no method by the configured name" do
    Wibawa.config.authenticate_with { true }
    expect(seen_user).to eq([ nil ])
    get "/admin/customers"
    expect(log.string.scan("Wibawa: config.current_user is :current_user, but ActionController::Base has no such method").size).to eq(1)
  end

  it "finds the user through a proc, as the Rails 8 authentication generator needs" do
    stub_const("Current", Struct.new(:user).new("Sari"))
    Wibawa.config.authenticate_with { head :forbidden unless Current.user }
    Wibawa.config.current_user = -> { Current.user }
    expect(seen_user).to eq([ "Sari" ])
    expect(log.string).not_to include("Wibawa:")
  end

  it "finds the user through the controller method, as Devise gives it" do
    Wibawa::ApplicationController.class_eval { private def current_user = "Budi" }
    Wibawa.config.authenticate_with { true }
    expect(seen_user).to eq([ "Budi" ])
    expect(log.string).not_to include("Wibawa:")
  ensure
    Wibawa::ApplicationController.send(:remove_method, :current_user)
  end

  it "mounts the engine below the app's own routes, so a route under the same path still wins" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      File.write(File.join(dir, "config/routes.rb"), %(Rails.application.routes.draw do\n  get "ops/login", to: "ops/sessions#new"\n  root "home#index"\nend\n))
      expect { Wibawa::Generators::InstallGenerator.start(%w[--skip-resources --path=/ops], destination_root: dir) }
        .to output(%r{Routes of your own under /ops .* must stay above the mount line}).to_stdout
      expect(File.read(File.join(dir, "config/routes.rb"))).to eq(%(Rails.application.routes.draw do\n  get "ops/login", to: "ops/sessions#new"\n  root "home#index"\n  mount Wibawa::Engine, at: "/ops"\nend\n))
      expect(File.read(File.join(dir, "config/initializers/wibawa.rb"))).to include("do not inherit from it", "Change this to your own")
    end
  end

  it "writes the Current.user line when the app has a Current model with a user" do
    initializer = lambda do |current|
      Dir.mktmpdir do |dir|
        FileUtils.mkdir_p(File.join(dir, "config"))
        File.write(File.join(dir, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
        if current
          FileUtils.mkdir_p(File.join(dir, "app/models"))
          File.write(File.join(dir, "app/models/current.rb"), current)
        end
        Wibawa::Generators::InstallGenerator.start(%w[--skip-resources --quiet], destination_root: dir)
        File.read(File.join(dir, "config/initializers/wibawa.rb")).lines.grep(/config\.current_user/).map(&:strip)
      end
    end

    rails8 = "class Current < ActiveSupport::CurrentAttributes\n  attribute :session\n  delegate :user, to: :session, allow_nil: true\nend\n"
    expect(initializer.(rails8)).to eq([ "config.current_user = -> { Current.user }" ])
    expect(initializer.(nil)).to eq([ "# config.current_user = -> { Current.user }", "config.current_user = :current_user" ])
    expect(initializer.("class Current < ActiveSupport::CurrentAttributes\n  attribute :account\nend\n")).to include("config.current_user = :current_user")
  end
end
