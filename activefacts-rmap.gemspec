# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activefacts/rmap/version'

Gem::Specification.new do |spec|
  spec.name          = "activefacts-rmap"
  spec.version       = Activefacts::RMap::VERSION
  spec.authors       = ["Clifford Heath"]
  spec.email         = ["clifford.heath@gmail.com"]

  spec.summary       = %q{Relational mapping for ActiveFacts}
  spec.description   = %q{Relational mapping for fact models. Part of the ActiveFacts suite.}
  spec.homepage      = "https://github.com/cjheath/activefacts-rmap"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.10"
  spec.add_development_dependency "rake", ">= 13"
  spec.add_development_dependency "rspec", "~> 3.3"

  spec.add_runtime_dependency "activefacts-metamodel", ">= 1.8", "~> 1"
end
