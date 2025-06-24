# From https://github.com/holman/dotfiles (MIT)
require 'rake'
require 'fileutils'

desc "Hook our dotfiles into system-standard positions."
task :install do
  skip_all = [false]
  overwrite_all = [false]
  backup_all = [false]

  # Find all dotfiles and dotdirectories
  dotfiles = Dir.glob('.*').reject { |f| %w[. .. .DS_Store .git .gitignore].include?(f) }
  
  dotfiles.each do |file|
    if File.directory?(file)
      # For directories, recursively find all files inside
      Dir.glob("#{file}/**/*", File::FNM_DOTMATCH).each do |nested_file|
        next if File.directory?(nested_file)
        next if nested_file.include?('.git/')
        
        install_file(nested_file, skip_all, overwrite_all, backup_all)
      end
    else
      # For regular files, install directly
      install_file(file, skip_all, overwrite_all, backup_all)
    end
  end
end

def install_file(file, skip_all, overwrite_all, backup_all)
  overwrite = false
  backup = false
  
  target = "#{ENV["HOME"]}/#{file}"
  
  # Ensure target directory exists
  FileUtils.mkdir_p(File.dirname(target))
  
  if File.exists?(target) || File.symlink?(target)
    unless skip_all[0] || overwrite_all[0] || backup_all[0]
      puts "File already exists: #{target}, what do you want to do? [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all"
      case STDIN.gets.chomp
      when 'o' then overwrite = true
      when 'b' then backup = true
      when 'O' then overwrite_all[0] = true
      when 'B' then backup_all[0] = true
      when 'S' then skip_all[0] = true
      when 's' then return
      end
    end
    FileUtils.rm_rf(target) if overwrite || overwrite_all[0]
    `mv "$HOME/#{file}" "$HOME/#{file}.backup"` if backup || backup_all[0]
  end
  
  `ln -s "$PWD/#{file}" "#{target}"`
end

task :uninstall do
  # Find all dotfiles and dotdirectories
  dotfiles = Dir.glob('.*').reject { |f| %w[. .. .DS_Store .git .gitignore].include?(f) }
  
  dotfiles.each do |file|
    if File.directory?(file)
      # For directories, recursively find all files inside
      Dir.glob("#{file}/**/*", File::FNM_DOTMATCH).each do |nested_file|
        next if File.directory?(nested_file)
        next if nested_file.include?('.git/')
        
        uninstall_file(nested_file)
      end
    else
      # For regular files, uninstall directly
      uninstall_file(file)
    end
  end
end

def uninstall_file(file)
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
