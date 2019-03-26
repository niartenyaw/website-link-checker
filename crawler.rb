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
    normalize(@to)
  end

  def from
    no_hash = @from.split('#').first
    normalize(no_hash)
  end

  def normalize(path)
    if path.start_with?('/')
      self.class.base + path
    elsif path.start_with?('#') || path.start_with?('..')
      from + path
    elsif path =~ /^[a-z0-9]/ && !path.start_with?('http')
      "#{self.class.base}/#{path}"
    else
      path
    end
  end

  def get
    self.class.get(to)
  rescue URI::InvalidURIError
    File.open('cannot_resolve.txt', 'a') do |file|
      file.write "#{to}\n"
    end

    nil
  end

  def in_scope?
    to.start_with? self.class.full_scope_path
  end

  def self.full_scope_path
    "#{base}#{scope}"
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
    until links.empty?
      assess links.shift
    end
  end

  private

  def clear_files
    File.open(@success_filename, 'w') {}
    File.open(@error_filename, 'w') {}
    File.open('cannot_resolve.txt', 'w') {}
  end

  def assess(link)
    puts "Assessing #{link.to}, #{links.length} left"
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
    if link.in_scope? && response.code == 200
      scrape(response) 
    end

    visited[link.to] = response.code
  end

  def record(link, code)
    case code
    when 200
      write(link, code, success_filename)
    when 301, 307
      # TODO: Follow redirects
      write(link, code, success_filename)
    else
      write(link, code, error_filename)
    end
  end

  def write(link, code, filename)
    File.open(filename, 'a') do |file|
      file.write "#{code} #{link.to} in #{link.from}\n"
    end
  end

  def scrape(response)
    request_path = response.request.path.to_s
    doc = Nokogiri::HTML response.body
    # TODO: make this configurable
    tags = doc.search('article')&.first&.search('a')
    tags&.each do |tag|
      path = tag.attributes['href']&.value
      links.push(Link.new(to: path, from: request_path)) if path
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
    scope: '/services/edge-lb/1.3'
  ).crawl
end
