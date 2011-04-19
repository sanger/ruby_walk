# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ruby_walk/version"

Gem::Specification.new do |s|
  s.name        = "ruby_walk"
  s.version     = RubyWalk::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Maxime Bourget"]
  s.email       = ["maxime.bourget@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{walk amongs dependencies of an object.}
  s.description = %q{call a block recursively on every object "dependencies" specified as a parameter. Can be use to iterate over a model or just generate a list of the dependencies.}

  s.rubyforge_project = "ruby_walk"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
