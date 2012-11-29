#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'

$parsed_options = nil

def abort_installation!
  p "Something went wrong :("
  p "Installation aborted."
  return false
end

def check_ruby_version
  p "Checking Ruby Version"
  ruby_version = `ruby --version`

  version_check = ruby_version.scan("ruby 1.8.7")
  patchlevel_check = ruby_version.scan("patchlevel 370")

  if version_check.empty?
    p "It seems you are not using the recommended ruby version."
    p "Please make sure you have installed 'ruby 1.8.7 (2012-02-08 patchlevel 370)'"
  elsif patchlevel_check.empty?
    p "It seems you are not running the recommended patch level."
    p "To avoid unexpected problems we would recommend to install 'ruby 1.8.7 (2012-02-08 patchlevel 370)'"
  else
    p "Found"
  end
end

def check_bundler
  p "Checking Bundler"
  unless system "bundle --version > /dev/null"
    p "It seems bundler is not installed. Please install bundler before running setup.rb."
    p "For bundler and more information visit: http://gembundler.com/"
    return false
  else
    p "Found"
    return true
  end
end

def check_git
  p "Checking git"
  unless system "git --version > /dev/null"
    p "It seems git is not installed. Please install git before running setup.rb."
    return false
  else
    p "Found"
    return true
  end
end

def check_for_db_yaml
  unless File.exists?(ROOT + '/config/database.yml')
    p "Please configure your database before installing openProject."
    p "Create and configure config/database.yml to do that."
    return false
  else
    return true
  end
end

def parse_argv(option)
  return $parsed_options if $parsed_options

  params_hash = {}

  name = nil
  ARGV.each do |param|
    if param[0,2] == "--"
      name = param
      params_hash[name] = []
    else
      params_hash[name] << param
    end
  end

  $parsed_options = params_hash[option] ? params_hash[option].inject(""){|result,a| result + a + " "} : ""
end

def checkout_default_plugins
  exec_dir = Dir.pwd + "/vendor"
  plugin_install_dir = Dir.pwd + "/vendor/plugins/"
  default_plugin_file = File.join(Dir.pwd, "plugin_config.yml")

  config = YAML.load_file(default_plugin_file)

  config.each_pair do |key, mod_config|

    Dir.chdir exec_dir
    plugin_path = File.join(exec_dir, key)


    if parse_argv("--force") and File.exists?(plugin_path)

      puts "Deleting #{plugin_path}.."
      FileUtils.rm_rf(plugin_path)
      return false
    end

    if mod_config.keys.include?("repository") and not File.exists?(plugin_path)
      system "git clone #{mod_config["repository"]} #{key}"
    end

    Dir.chdir plugin_path

    if mod_config.keys.include?("branch")
      unless `git branch`.split.include?(mod_config['branch'])
        system "git branch #{mod_config["branch"]} origin/#{mod_config["branch"]}"
      end

      if `git branch | grep '*'`.delete('*').chomp.strip != mod_config["branch"]
        system "git checkout #{mod_config["branch"]}"
        system "git merge origin/#{mod_config["branch"]}"
      else
        system "git merge origin/#{mod_config["branch"]}"
      end
    end

    if mod_config.keys.include?("commit")
      system "git reset #{mod_config['commit']}"
    end

    Dir.chdir exec_dir
  end
end

def setup_openproject
  p "Installing Gems via Bundler"

  unless system("bundle install --without rmagick " + parse_argv("--without"))
    return false
  end

  if check_for_db_yaml
    puts "Creating database"

    if parse_argv("--force")
      return false unless system("rake db:drop:all")
    end

    return false unless system("rake db:create:all") and migrate_core and migrate_plugins
  else
    return false
  end

  p "Generate Session Store"
  system("rake generate_session_store")
end

def bundle_default_plugins
  unless system("bundle install --without rmagick")
    return false
  end
end

def migrate_plugins
  p "Migrate Plugins"
  return system("rake db:migrate:plugins")
end

def migrate_core
  p "Migrate Core"
  return system("rake db:migrate")
end

def install
  p 'Installing openProject...'


  check_ruby_version
  if not check_bundler or not check_git # check for dependencies
    return abort_installation!
  end

  unless checkout_default_plugins # clone plugins
    return abort_installation!
  end

  Dir.chdir ROOT

  return abort_installation! unless setup_openproject # Start installation
end

ROOT = Dir.pwd
install
