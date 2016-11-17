# Fix line breaks issues caused by resizing terminal:
# http://stackoverflow.com/questions/12105016/line-breaks-when-using-rails-consoleterminal#comment65110222_12108289
Signal.trap('SIGWINCH', proc { y, x = `stty size`.split.map(&:to_i) } )

# `reload!` for non-Rails IRB sessions
# http://www.seanbehan.com/ruby-reload-method-in-non-rails-irb-sessions
unless defined?(reload!)
  $files = []
  def load!(file)
    $files << file
    load file
  end
  def reload!
    $files.each { |f| load f }
  end
end

# Save IRB history between sessions
# http://stackoverflow.com/a/11137143
IRB.conf[:SAVE_HISTORY] = 1000
