#!/usr/bin/ruby

# OCRemix Filtered Downloader
# Written by Ricky Mondello
# http://github.com/rmondello/SOMETHING

# TODO: Test with a lack of network connection.
# TODO: Pick a random mirror.

require 'rubygems'
require 'ruby-debug'

require 'rss/1.0'
require 'rss/2.0'
require 'open-uri'
require 'net/http'
require 'date'

# Constants
SOURCE_FEED = "http://www.ocremix.org/feeds/ten20/"
DATE_FILE = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + ".last_attempt"

# Arguments and debug mode
title_string, path_string, debug_string = ARGV
unless title_string && path_string
  $stderr.puts "usage: ocremix.rb title_filter_pattern download_directory [debug]"
  $stderr.puts ""
  $stderr.puts "example: ocremix.rb all iTunes"
  $stderr.puts "example: ocremix.rb 'Sonic' 'downloads/'"
  exit 1
end

begin
  if /\*|all|everything/i.match(title_string) != nil
    title_string = ""
  end
  title_regex = Regexp.new(title_string)
rescue
  $stderr.puts "error: bad regular expression, " + title_string
  exit 1
end

if /iTunes/i.match(path_string) != nil
  path_string = "~/Music/iTunes/iTunes Music/Automatically Add to iTunes/"
end

path_prefix = File.expand_path path_string
unless File.directory? path_prefix
  $stderr.puts "error: directory " + path_prefix + " does not exist"
  exit 1
end

$debug = true if debug_string

# Functions
def get_download_link_from_page(url)
  http_response = Net::HTTP.get_response(URI.parse(url))
  response_body = http_response.body
  match = /http:\/\/.*mp3/.match response_body
  match != nil ? match[0].strip : nil
end

def download_and_write_file_if_necessary(url, path_prefix)
  filename = url.split("/").last
  path = path_prefix + File::SEPARATOR + filename
  if File.exist? path
    puts "File already exists. Not written."
    return
  end

  http_response = Net::HTTP.get_response(URI.parse(url))
  response_body = http_response.body
  
  f = File.new(path, "w")
  f.write(response_body)
  f.close
    
  puts "File: " + path if $debug
end

def get_rss_object(feed_url)
  content = ""
  open(feed_url) { |s| content = s.read }
  RSS::Parser.parse(content, false)
end

def get_last_attempt()
  begin
    Time.at(File.open(DATE_FILE, "rb").read.to_i)
  rescue
    nil
  end
end

def write_date_to_disk()
  f = File.new(DATE_FILE, "w")
  f.write Time.now.to_i
  f.close
end



last_attempt = get_last_attempt()
puts "Last attempt: " + (last_attempt ? last_attempt.to_s : "Never") + "\n" if $debug

rss = get_rss_object(SOURCE_FEED)
rss.items.each do |item|
  if last_attempt
    next if item.date < last_attempt
  end
  
  if (title_regex.match item.title) != nil
    page_url = item.guid.content.sub("www.", "")
    next if page_url == nil
    
    link_to_mp3 = get_download_link_from_page(page_url)
    if $debug
      puts "Title: " + item.title
      puts "Page: " + page_url
      puts "MP3: " + link_to_mp3
    end
    
    download_and_write_file_if_necessary(link_to_mp3, path_prefix)
    
    puts "" if $debug
  end
end

# Update the last checked date.
write_date_to_disk
