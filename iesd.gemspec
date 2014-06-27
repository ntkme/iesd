Gem::Specification.new do |s|
  s.required_ruby_version = ">= 1.9.2"

  s.name                  = "iesd"
  s.version               = "1.2.1"
  s.summary               = "Customize OS X InstallESD."
  s.description           = "Modify Extensions, Kextcache and Packages on InstallESD."
  s.authors               = "なつき"
  s.email                 = "i@ntk.me"
  s.homepage              = "https://github.com/ntkme/iesd"
  s.license               = "BSD-2-Clause"

  s.executables           = ["iesd"]
  s.files                 = %w[
    README.md
    LICENSE.md
    bin/iesd
    iesd.gemspec
  ] + Dir["lib/**/*.rb"]
end
