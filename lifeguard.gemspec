# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lifeguard/version'

Gem::Specification.new do |spec|
  spec.name          = "lifeguard"
  spec.version       = Lifeguard::VERSION
  spec.authors       = ["Brian Stien"]
  spec.email         = ["brian.stien@moneydesktop.com"]
  spec.summary       = %q{A Supervised threadpool implementation in ruby.}
  spec.description   = %q{Do you have a threadpool? Do you need someone to watch it? Look no further!}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "better_receive"
  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-pride"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "special_delivery"
end
