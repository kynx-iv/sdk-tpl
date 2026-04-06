# frozen_string_literal: true

require_relative "lib/sdk_tpl/version"

Gem::Specification.new do |spec|
  spec.name          = "{{SDK_SLUG}}"
  spec.version       = SdkTpl::VERSION
  spec.authors       = ["{{GITHUB_ORG}}"]
  spec.summary       = "{{SDK_NAME}} Ruby SDK"
  spec.description   = "Official Ruby SDK for the {{SDK_NAME}} API. " \
                        "Provides a high-level client with built-in retry logic, " \
                        "circuit breaking, request signing, and error sanitization."
  spec.homepage      = "https://github.com/{{GITHUB_ORG}}/{{SDK_SLUG}}-ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files         = Dir["lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "faraday", "~> 2.0"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.19"
end
