class Chunk
  attr_accessor :offset, :size, :file_remote_path, :file_local_path, :buffer_size
  attr_reader :download_thread, :merge_thread, :file_tmp_path

  def initialize args
    @buffer_size = 16000000 #16 mb
    # todo - throw exception if any of the attr_accessor props are nil
    args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end
    @file_tmp_path = @offset.to_s+".tmp"
  end

  def download!(sftp)
    puts "downloading chunk #{offset} to #{@file_tmp_path}".magenta
    File.open(@file_tmp_path, 'w') do |tmp|
      remote = sftp.file.open(@file_remote_path, "r")
      remote.pos = @offset #set our seek position to the offset
      while remote.pos < @offset + @size do
        puts "downloading from #{remote.pos}"
        buffer = remote.read([@buffer_size, @offset + @size - remote.pos].min)
        tmp << buffer
        puts remote.pos
      end
    end
    puts "done downloading chunk #{offset}".green
  end

  def download
    #asynchronous download of chunk
  end

  def merge!
    #synchronous merge of @file_tmp into @file_local
  end

  def merge
    #asynchronous merge of @file_tmp into @file_local
  end

  def wait_download
    #blocks until download is complete
  end

  def wait_merge
    #blocks until merge is complete
  end
end
