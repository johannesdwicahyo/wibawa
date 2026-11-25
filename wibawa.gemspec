require_relative "lib/wibawa/version"

Gem::Specification.new do |spec|
  spec.name        = "wibawa"
  spec.version     = Wibawa::VERSION
  spec.authors     = [ "Johannes Dwi Cahyo Kristanto" ]
  spec.email       = [] # TODO: add the address you want public on RubyGems
  spec.summary     = "A modern admin framework for Rails: ActiveAdmin ergonomics on ViewComponent, Hotwire and Tailwind."
  spec.description = <<~DESC
    Wibawa gives Rails apps a full admin panel from one small Ruby file per model:
    scopes, filters, search, sortable index tables, batch and member actions,
    nested forms, CSV export and authorization adapters. It is built on
    ViewComponent and Turbo, and ships prebuilt Tailwind CSS, so host apps need
    no Node, no Sass and no asset configuration.
  DESC
  spec.homepage = "https://github.com/johannesdwicahyo/wibawa"
  spec.license  = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "railties", ">= 7.2"
  spec.add_dependency "activerecord", ">= 7.2"
  spec.add_dependency "actionpack", ">= 7.2"
  spec.add_dependency "view_component", ">= 3.12"
  spec.add_dependency "turbo-rails", ">= 2.0"
  spec.add_dependency "csv"
end
