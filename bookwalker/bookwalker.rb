#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'nokogiri'
require 'addressable/uri'

class Options < Struct.new(:fastladder_url, :fastladder_api_key, :replace_url)
  REQUIRED = [:fastladder_url, :fastladder_api_key]

  class ValidationError < StandardError
  end

  def validate!
    REQUIRED.each do |attr|
      if self[attr].nil?
        raise ValidationError.new("#{attr} must be set")
      end
    end
    true
  end

  def fastladder_uri
    Addressable::URI.parse(fastladder_url)
  end

  def replace_uri
    Addressable::URI.parse(replace_url)
  end
end

def replace_host(options, url)
  if options.replace_url
    uri = Addressable::URI.parse(url)
    uri.host = options.replace_uri.host
    uri.scheme = options.replace_uri.scheme
    uri.to_s
  else
    url
  end
end

options = Options.new
options.fastladder_url = ENV['FASTLADDER_URL']
options.fastladder_api_key = ENV['FASTLADDER_API_KEY']
options.replace_url = ENV['REPLACE_URL']
options.validate!

feeds = []

Net::HTTP.new('bookwalker.jp', 443).tap do |https|
  https.use_ssl = true
  https.start do
    [2, 3].each do |ct|
      path = "/new/ct#{ct}/"
      res = https.get(path)
      if res.code.to_i != 200
        raise "#{path}: #{res.code}"
      end

      doc = Nokogiri::HTML.parse(res.body)
      doc.css('.bookItemInner').each do |item|
        h3 = item.at_css('.img-book')
        img = item.at_css('img')['src']
        link = h3.at_css('a')['href']
        guid = Addressable::URI.parse(link).join('..').path
        title = item.at_css('.book-tl').inner_text
        price = item.at_css('.book-price, .book-series').inner_text
        author = item.at_css('.book-name').inner_text
        shop = item.at_css('.shop-name').inner_text
        feed = {
          feedlink: "https://bookwalker.jp#{path}",
          feedtitle: "BOOK WALKER ct#{ct}",
          title: title,
          link: link,
          guid: guid,
          body: %Q|<img src="#{replace_host(options, img)}"/><p>#{author}</p><p>#{shop}</p><p>#{price}</p>|,
          author: author,
          category: 'bookwalker',
        }
        feeds << feed
      end
    end
  end
end

scheme = options.fastladder_uri.scheme
port = options.fastladder_uri.port || Addressable::URI.port_mapping[scheme]
http = Net::HTTP.new(options.fastladder_uri.host, port)
if scheme == 'https'
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
end
http.start do
  q = {
    api_key: options.fastladder_api_key,
    feeds: feeds.to_json,
  }.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v)}" }.join('&')
  res = http.post('/rpc/update_feeds', q)
  if res.code.to_i != 200
    raise "/rcp/update_feeds: #{res.code}"
  end
end
