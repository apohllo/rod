# encoding: utf-8
require 'fileutils'

module Rod
  module Utils
    # Removes single file.
    def remove_file(file_name)
      Utils.remove_file(file_name)
    end

    # Removes single file (singleton method).
    def self.remove_file(file_name)
      if test(?f,file_name)
        File.delete(file_name)
        puts "Removing #{file_name}" if $ROD_DEBUG
      else
        puts "#{file_name} is not a file." if $ROD_DEBUG
      end
    end

    # Remove all files matching the +pattern+.
    # If +skip+ given, the file with the given name is not deleted.
    def remove_files(pattern,skip=nil)
      Dir.glob(pattern).each do |file_name|
        remove_file(file_name) unless file_name == skip
      end
    end

    # Removes all files which are similar (i.e. are generated
    # by RubyInline for the same class) to +name+
    # excluding the file with exactly the name given.
    def remove_files_but(name)
      remove_files(name.sub(INLINE_PATTERN_RE,"*"),name)
    end

    # Reports progress of long-running operation.
    # The +index+ is the current operation's step
    # of +count+ steps.
    def report_progress(index,count)
      step = (count.to_f/50).to_i
      return if step == 0
      if index % step == 0
        if index % (5 * step) == 0
          print "#{(index / (5 * step) * 10)}%"
        else
          print "."
        end
      end
    end

    # Removes a margin from a string, usually a here-doc.
    # If +n+ is provided the result is shifted right for n spaces.
    #
    #  s =<<-END
    #  |def abc
    #  |  puts "x"
    #  |end
    #  END
    #
    #  margin(s) =>
    #
    #  def abc
    #    puts "x"
    #  end
    def self.remove_margin(string,n=0)
      d = ((/\A.*\n\s*(.)/.match(string)) ||
          (/\A\s*(.)/.match(string)))[1]
      return '' unless d
      if n == 0
        string.gsub(/\n\s*\Z/,'').gsub(/^\s*[#{d}]/, '')
      else
        string.gsub(/\n\s*\Z/,'').gsub(/^\s*[#{d}]/, ' ' * n)
      end
    end

    # Converts the model +name+ to the C struct name.
    def self.struct_name_for(name)
      name.underscore.gsub(/\//,"__")
    end
  end
end
