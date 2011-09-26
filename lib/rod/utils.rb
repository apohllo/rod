# encoding: utf-8
require 'fileutils'

module Rod
  module Utils
    # Removes single file.
    def remove_file(file_name)
      if test(?f,file_name)
        File.delete(file_name)
        puts "Removing #{file_name}" if $ROD_DEBUG
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
  end
end
