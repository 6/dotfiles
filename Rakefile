# From https://github.com/holman/dotfiles (MIT)
require 'rake'

current_directory_dotfiles = '\.[^\.]*'

desc "Hook our dotfiles into system-standard positions."
task :install do
  skip_all = false
  overwrite_all = false
  backup_all = false

  Dir.glob(current_directory_dotfiles).each do |file|
    next  if %w[.DS_Store .git settings.local.json].include?(file)

    overwrite = false
    backup = false

    target = "#{ENV["HOME"]}/#{file}"

    if File.exists?(target) || File.symlink?(target)
      unless skip_all || overwrite_all || backup_all
        puts "File already exists: #{target}, what do you want to do? [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all"
        case STDIN.gets.chomp
        when 'o' then overwrite = true
        when 'b' then backup = true
        when 'O' then overwrite_all = true
        when 'B' then backup_all = true
        when 'S' then skip_all = true
        when 's' then next
        end
      end
      FileUtils.rm_rf(target) if overwrite || overwrite_all
      `mv "$HOME/#{file}" "$HOME/#{file}.backup"` if backup || backup_all
    end
    `ln -s "$PWD/#{file}" "#{target}"`
  end
end

task :uninstall do

  Dir.glob(current_directory_dotfiles).each do |file|

    target = "#{ENV["HOME"]}/#{file}"

    # Remove all symlinks created during installation
    if File.symlink?(target)
      FileUtils.rm(target)
    end

    # Replace any backups made during installation
    if File.exists?("#{ENV["HOME"]}/#{file}.backup")
      `mv "$HOME/#{file}.backup" "$HOME/#{file}"`
    end

  end
end
