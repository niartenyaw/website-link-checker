#!/usr/bin/env ruby

require 'nokogiri'
require 'httparty'
require 'byebug'
require_relative 'linked_list'

class Link
  include HTTParty

  def self.scope=(scope = nil)
    @scope = scope
  end

  def self.base=(base = nil)
    base_uri(base)
    @base = base
  end

  def self.scope
    @scope
  end

  def self.base
    @base
  end

  def initialize(to:, from:)
    raise ArgumentError unless from.start_with?('http')
    raise NotImplementedError unless self.class.scope
    raise NotImplementedError unless self.class.base

    @to = to
    @from = from
  end

  def to
    no_hash(normalize(@to))
  end

  def no_hash(path)
    path.split('#').first
  end

  def from
    no_hash(normalize(@from))
  end

  def from_path
    from[self.class.base.length..-1]
  end

  def normalize(path)
    if path.start_with?('/') || path.empty?
      self.class.base + path
    elsif path.start_with?('#', '..')
      self.class.base + Pathname.new(from_path + path).cleanpath.to_path
    elsif path =~ /^[a-z0-9]/ && !path.start_with?('http', 'mailto:')
      "#{ self.class.base }/#{ path }"
    else
      path
    end
  end

  def get
    if to.include?('dcos_generate_config.sh') ||
       to.include?('dcos_generate_config.ee.sh') ||
       to.start_with?('mailto:')
      return nil
    end

    self.class.get(to, limit: 10)
  rescue URI::InvalidURIError => e
    log_error(e)
  rescue SocketError => e
    log_error(e)
  rescue Errno::ECONNREFUSED => e
    log_error(e)
  rescue OpenSSL::SSL::SSLError => e
    log_error(e)
  rescue
    puts "Error in #{from } with #{ to }"
  end

  def log_error(error)
    File.open('cannot_resolve.txt', 'a') do |file|
      file.write "#{ to }, #{ error.message }\n"
    end

    nil
  end

  def in_scope?
    to.start_with? self.class.full_scope_path
  end

  def self.full_scope_path
    "#{ base }#{ scope }"
  end
end

class Crawler
  def initialize(base:, scope:)
    Link.base = base
    Link.scope = scope

    @links = Array.new
    @links.push(Link.new(to: scope, from: base + scope))

    @visited = Hash.new

    @error_filename = 'errors.txt'
    @success_filename = 'success.txt'

    clear_files
  end

  def crawl
    assess links.shift until links.empty?
  end

  private

  def clear_files
    File.open(@success_filename, 'w') {}
    File.open(@error_filename, 'w') {}
    File.open('cannot_resolve.txt', 'w') {}
  end

  def assess(link)
    puts "Assessing #{ link.to }, #{ links.length } left"
    if visited.key? link.to
      record link, visited[link.to]
    else
      visit link
    end
  end

  def visit(link)
    response = link.get

    return unless response

    record(link, response.code)

    scrape(response) if link.in_scope? && response.code == 200

    visited[link.to] = response.code
  end

  def record(link, code)
    case code
    when 200
      write(link, code, success_filename)
    else
      write(link, code, error_filename)
    end
  end

  def write(link, code, filename)
    File.open(filename, 'a') do |file|
      file.write "#{ code } #{ link.to } in #{ link.from }\n"
    end
  end

  def scrape(response)
    request_path = response.request.path.to_s
    tags(response).each do |tag|
      path = tag.attributes['href']&.value

      links.push(Link.new(to: path, from: request_path)) if path
    end
  end

  def tags(response)
    doc = Nokogiri::HTML response.body
    # TODO: make this configurable
    article = doc.search('article')&.first
    if article
      article.search('a') || []
    else
      doc.search('a') || []
    end
  end

  attr_reader :success_filename,
              :error_filename,
              :scope,
              :links,
              :base,
              :visited
end

if $PROGRAM_NAME == __FILE__
  Crawler.new(
    base: 'https://docs.mesosphere.com',
    scope: ''
  ).crawl
end
