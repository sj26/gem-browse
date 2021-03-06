require 'rubygems/browse/command'

class Gem::Commands::CloneCommand < Gem::Browse::Command

  def description
    <<-EOF
The clone command performs a Git clone of a gem's upstream repository.
It looks for this repository by checking the homepage field of the gemspec
and the source code URL field at rubygems.org.  Currently, only GitHub
repositories are recognized.
    EOF
  end

  def initialize
    super 'clone', "Clone a gem's source from GitHub"
    add_editor_option
    add_option('-o', '--[no-]open', 'Open in editor afterwards') do |open, options|
      options[:open] = open
    end
    add_option('-d', '--directory DIR', 'Parent directory to clone into') do |directory, options|
      options[:directory] = directory
    end
  end

  def execute
    name = get_one_gem_name
    json = nil

    homepage =
      begin
        find_by_name(name).homepage
      rescue Gem::LoadError
        json = get_json(name)
        json[/"homepage_uri":\s*"([^"]*)"/, 1]
      end

    unless url = repo(homepage)
      json ||= get_json(name)
      unless url = repo(json[/"source_code_uri":\s*"([^"]*)"/, 1])
        alert_error "Could not find a GitHub URL for #{name}"
        terminate_interaction 1
      end
    end

    target = File.join(*[options[:directory], url[/([^\/]*)\.git$/, 1]].compact)
    unless system('git', 'clone', url, target)
      alert_error "Failed to clone #{url}"
      terminate_interaction 1
    end

    if options[:open]
      Dir.chdir(target) do
        edit('.')
      end
    end
  end

  def repo(url)
    case url.to_s
    when %r{://(?:wiki\.)?github\.com/([^/]*/[^/]*)}
      "git://github.com/#$1.git"
    when %r{://([^./]*)\.github\.com/([^/]*)}
      "git://github.com/#$1/#$2.git"
    end
  end

end
