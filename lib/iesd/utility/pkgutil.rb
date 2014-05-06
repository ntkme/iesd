require "tmpdir"
require_relative "tty"

module PKGUtil
  def self.read input
    Dir.mktmpdir { |tmp|
      tmp = File.join tmp, File.basename(input)
      expand input, tmp
      if block_given?
        yield tmp
      else
        shell tmp
      end
    }
  end

  def self.write input, output = input
    Dir.mktmpdir { |tmp|
      tmp = File.join tmp, File.basename(input)
      expand input, tmp
      if block_given?
        yield tmp
      else
        shell tmp
      end
      flatten tmp, output
    }
  end

  private

  def self.expand pkg, dir
    ohai "Expanding #{pkg}"
    system("/usr/bin/env", "pkgutil", "--expand", pkg, dir)
    puts "Expanded: #{dir}"
  end

  def self.flatten dir, pkg
    ohai "Flattening #{dir}"
    system("/usr/bin/env", "pkgutil", "--flatten", dir, pkg)
    puts "Flattened: #{pkg}"
  end

  def self.shell dir
    Dir.chdir(dir) {
      ohai ENV['SHELL']
      Kernel.system ENV, ENV['SHELL']
    }
  end
end

module PKGUtil
  class PKG
    attr_accessor :url

    def initialize url
      @url = File.absolute_path url
    end

    def show &block
      PKGUtil.read(@url, &block)
    end

    def edit
      update
    end

    def update &block
      PKGUtil.write(@url, &block)
    end
  end
end
