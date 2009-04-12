# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{miyazakiresistance}
  s.version = "0.0.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tsukasa OISHI"]
  s.date = %q{2009-04-12}
  s.description = %q{MiyazakiResistance is a library like ActiveRecord to use Tokyo Tyrant.}
  s.email = ["tsukasa.oishi@gmail.com"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.rdoc"]
  s.files = ["History.txt", "Manifest.txt", "README.rdoc", "Rakefile", "lib/miyazakiresistance.rb", "lib/miyazaki_resistance/base.rb", "lib/miyazaki_resistance/error.rb", "lib/miyazaki_resistance/miyazaki_logger.rb", "lib/miyazaki_resistance/tokyo_connection.rb", "initializers/rdb.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://www.kaeruspoon.net/keywords/MiyazakiResistance}
  s.post_install_message = %q{PostInstall.txt}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{miyazakiresistance}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{MiyazakiResistance is a library like ActiveRecord to use Tokyo Tyrant.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<newgem>, [">= 1.2.3"])
      s.add_development_dependency(%q<hoe>, [">= 1.8.0"])
    else
      s.add_dependency(%q<newgem>, [">= 1.2.3"])
      s.add_dependency(%q<hoe>, [">= 1.8.0"])
    end
  else
    s.add_dependency(%q<newgem>, [">= 1.2.3"])
    s.add_dependency(%q<hoe>, [">= 1.8.0"])
  end
end
