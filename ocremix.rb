#!/usr/bin/ruby

# OCRemix Filtered Downloader
# Written by Ricky Mondello
# https://github.com/rmondello/OverClocked-ReMix-Downloader

require 'rss/1.0'
require 'rss/2.0'
require 'open-uri'
require 'net/http'

# Constants
SOURCE_FEED = "http://www.ocremix.org/feeds/ten20/"
HISTORY_FILE = File.expand_path(File.dirname(__FILE__)) + File::SEPARATOR + ".ocremix_history"

# Arguments and debug mode
title_string, path_string, debug_string = ARGV
unless title_string && path_string
  $stderr.puts "usage: ocremix.rb title_filter_pattern download_directory [debug]"
  $stderr.puts ""
  $stderr.puts "example: ocremix.rb all iTunes"
  $stderr.puts "example: ocremix.rb 'Sonic' 'downloads/'"
  exit 1
end

# Useful in converting history representation (file -> string -> array -> hash)
module Enumerable
  def to_hash
    self.inject({}) { |h, i| h[i] = i; h }
  end
end

# Parse the search query
begin
  if /\*|all|everything/i.match(title_string) != nil
    title_string = ""
  end
  title_regex = Regexp.new(title_string)
rescue
  $stderr.puts "error: bad regular expression, " + title_string
  exit 1
end

# Parse the download path
if /iTunes/i.match(path_string) != nil
  path_string = "~/Music/iTunes/iTunes Media/Automatically Add to iTunes/"
end
path_prefix = File.expand_path path_string
unless File.directory? path_prefix
  $stderr.puts "error: directory " + path_prefix + " does not exist"
  exit 1
end

$debug = true if debug_string

def get_download_link_from_page(url)
  http_response = Net::HTTP.get_response(URI.parse(url))
  response_body = http_response.body
  match = /http:\/\/.*mp3/.match response_body
  match != nil ? match[0].strip : nil
end

def download_and_write_file(url, path_prefix)
  filename = url.split("/").last
  path = path_prefix + File::SEPARATOR + filename
  puts "  Downloading: #{url}" if $debug
  http_response = Net::HTTP.get_response(URI.parse(url))
  File.open(path, 'w') {|f| f.write http_response.body }
  puts "  Written: #{path}" if $debug
end

def get_rss_object(feed_url)
  content = ""
  open(feed_url) { |s| content = s.read }
  RSS::Parser.parse(content, false)
end

def read_history_from_disk()
  begin
    File.open(HISTORY_FILE, "rb").read.split("\n").to_hash
  rescue
    {}
  end
end

def write_history_to_disk(h)
  f = File.new(HISTORY_FILE, "w")
  f.write h.keys.sort.join "\n"
  f.close
end

h = read_history_from_disk
rss = get_rss_object(SOURCE_FEED)
rss.items.each do |item|
  item_key = item.guid.content
  puts "#{item.title} (#{item_key})" if $debug
  if h.has_key? item_key
    print "  Skipping: Already in history file.\n\n" if $debug
    next
  end

  if (title_regex.match item.title) == nil
    print "  Skipping: Does not match input pattern #{title_regex.source}\n\n"
    next
  end

  page_url = item.guid.content.sub("www.", "")
  link_to_mp3 = get_download_link_from_page(page_url)
  download_and_write_file(link_to_mp3, path_prefix)
  h[item_key] = item_key

  print "\n" if $debug
end

write_history_to_disk h
