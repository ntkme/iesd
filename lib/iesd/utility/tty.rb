require "shellwords"

module Tty extend self
  def blue; bold 34; end
  def white; bold 39; end
  def red; underline 31; end
  def yellow; underline 33 ; end
  def reset; escape 0; end
  def em; underline 39; end
  def green; color 92 end
  def gray; bold 30 end

  def width
    `/usr/bin/tput cols`.strip.to_i
  end

  def truncate(str)
    str.to_s[0, width - 4]
  end

  private

  def color n
    escape "0;#{n}"
  end
  def bold n
    escape "1;#{n}"
  end
  def underline n
    escape "4;#{n}"
  end
  def escape n
    "\033[#{n}m" if $stdout.tty?
  end
end

def ohai title, *sput
  title = Tty.truncate(title) if $stdout.tty? && ENV['VERBOSE'].nil?
  puts "#{Tty.blue}==>#{Tty.white} #{title}#{Tty.reset}"
  puts sput unless sput.empty?
end

def oh1 title
  title = Tty.truncate(title) if $stdout.tty? && ENV['VERBOSE'].nil?
  puts "#{Tty.green}==>#{Tty.white} #{title}#{Tty.reset}"
end

def opoo warning
  STDERR.puts "#{Tty.red}Warning#{Tty.reset}: #{warning}"
end

def onoe error
  lines = error.to_s.split("\n")
  STDERR.puts "#{Tty.red}Error#{Tty.reset}: #{lines.shift}"
  STDERR.puts lines unless lines.empty?
end

def odie error
  onoe error
  exit 1
end

def system *args
  abort "Failed during: #{args.shelljoin}" unless Kernel.system *args
end

def sudo *args
  args = if args.length > 1
    args.unshift "/usr/bin/sudo"
  else
    "/usr/bin/sudo #{args.first}"
  end
  ohai *args
  system *args
end
