
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fop/version"

Gem::Specification.new do |spec|
  spec.name          = "fop"
  spec.version       = Fop::VERSION
  spec.authors       = ["Sorah Fukumori"]
  spec.email         = ["her@sorah.jp"]

  spec.summary       = %q{scraping client of Japan Airlines FOP/Mileage calculator}
  spec.homepage      = "https://github.com/sorah/fop"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
end
