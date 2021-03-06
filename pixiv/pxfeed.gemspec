# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pxfeed/version'

Gem::Specification.new do |spec|
  spec.name          = "pxfeed"
  spec.version       = PxFeed::VERSION
  spec.authors       = ["eagletmt"]
  spec.email         = ["eagletmt@gmail.com"]
  spec.description   = "PxFeed"
  spec.summary       = "PxFeed"
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/) rescue []
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "addressable"
  spec.add_dependency "faraday"
  spec.add_dependency "faraday-cookie_jar"
  spec.add_dependency "nokogiri"
  spec.add_dependency "thor"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end
