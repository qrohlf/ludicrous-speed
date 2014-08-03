class Chunk
  require 'fileutils'
  attr_accessor :offset, :size, :file_remote_path, :file_local_path, :buffer_size
  attr_reader :download_thread, :merge_thread, :file_tmp_path

  def initialize args
    @buffer_size = 6400
    # todo - throw exception if any of the attr_accessor props are nil
    args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
    @file_tmp_path = @offset.to_s+".tmp"
    @download_complete = false
  end

  def download!(sftp)
    puts "downloading chunk #{offset} to #{@file_tmp_path}".magenta
    File.open(@file_tmp_path, 'w') do |tmp|
      remote = sftp.file.open(@file_remote_path, "r")
      remote.pos = @offset #set our seek position to the offset
      while remote.pos < @offset + @size do
        # puts "downloading from #{remote.pos}"
        buffer = remote.read([@buffer_size, @offset + @size - remote.pos].min)
        tmp << buffer
        # puts remote.pos
      end
    end
    puts "done downloading chunk #{offset}".green
    @download_complete = true
  end

  def merge!
    #synchronous merge of @file_tmp into @file_local
    File.open(@file_local_path, 'a+') do |local|
      local.seek(@offset, IO::SEEK_SET)
      File.open(@file_tmp_path, 'r') do |temp|
        IO::copy_stream(temp, local, @size)
      end
    end
    # FileUtils.rm @file_tmp_path
    puts "merged chunk #{@offset} into #{@file_local_path}"
  end

  def wait
    sleep(1) until @download_complete
  end

  def download_completed(&block)
    @completed_callback = block
  end

end
