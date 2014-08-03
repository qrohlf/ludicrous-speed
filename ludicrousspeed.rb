#!/usr/bin/env ruby

require 'net/sftp'
require 'colorize'
require 'filesize'
require 'uri'
require './chunk'


# usage: ./ludicrousspeed.rb user:pass@domain.com /path/to/file

uri = URI.parse('sftp://' + ARGV[0])
@user = uri.user
@pass = uri.password
@host = uri.host
@file_remote_path = ARGV[1]
@file_local_path = File.basename(@file_remote_path)
@chunk_count=5
@worker_count=5

if File.exists? @file_local_path
  puts "File exists - aborting!".yellow
  exit
end

puts "Logging in...".cyan

Net::SFTP.start(@host, @user, password: @pass) do |sftp|
  puts "Login successful!".green
  puts "Getting file info for #{@file_remote_path}".cyan
  sftp.file.open(@file_remote_path, "r") do |f|
    @bytes = f.stat.size
  end
end

puts "File is #{@bytes}B (#{Filesize.from(@bytes.to_s+" B").pretty})"
@chunksize=(@bytes/@chunk_count).ceil
puts "Downloading in #{@chunk_count} chunks using #{@worker_count} workers. Chunk size is #{Filesize.from(@chunksize.to_s+" B").pretty}"

@chunks = []
pos = 0;
while(pos < @bytes) do
  chunk = Chunk.new(
    offset: pos,
    size: [@chunksize, @bytes - pos].min, #don't go past the end of the file!
    file_remote_path: @file_remote_path, #mustn't forget to close this!
    file_local_path: @file_local_path
  )
  pos += chunk.size
  @chunks << chunk
  puts "#{chunk.offset} - #{chunk.offset + chunk.size}"
end

@download_queue = @chunks.clone

# Spin up some worker threads
@workers = []
@worker_count.times do |i|
  @workers << Thread.new(i) do |index|
    puts "Worker #{index} started!"
    Net::SFTP.start(@host, @user, password: @pass) do |sftp|
      puts "Worker #{index} logged in!".green
      while @download_queue.size > 0
        c = @download_queue.shift
        c.download!(sftp)
      end
    end
    puts "Worker #{index} finished!"
  end
end

# Combine the results on the main thread in order as they finish downloading
@chunks.each do |c|
  c.wait
  puts "chunk count is #{@chunks.size}"
  c.merge!
end

#wait for workers to finish
@workers.each { |thr| thr.join }
puts "Done with all chunks".green
