require 'addressable/uri'
require 'faraday'
require 'json'
require 'thor'

require 'pxfeed/fetcher'
require 'pxfeed/version'

module PxFeed
  class CLI < Thor
    desc 'post', 'Post news to Fastladder'
    option :bookmark,
      desc: 'Enable bookmark_new_illust mode',
      type: :boolean,
      aliases: %w[-b]
    option :dry_run,
      desc: "Dry run - don't post to Fastladder",
      type: :boolean,
      aliases: %w[-n]
    option :words,
      desc: 'Path to the file containing words',
      type: :string,
      aliases: %w[-w]
    option :users,
      desc: 'Path to the file containing user ids',
      type: :string,
      aliases: %w[-u]
    def post
      words = []
      user_ids = []

      if options[:words]
        open(options[:words]) do |f|
          f.each_line { |word| words << word.chomp }
        end
      end
      if options[:users]
        open(options[:users]) do |f|
          f.each_line { |user_id| user_ids << user_id.chomp.to_i }
        end
      end

      pixiv_username = ENV['PIXIV_USERNAME']
      pixiv_password = ENV['PIXIV_PASSWORD']
      api_key = ENV['FASTLADDER_API_KEY']

      fetcher = PxFeed::Fetcher.new
      fl = Faraday::Connection.new do |builder|
        builder.url_prefix = ENV['FASTLADDER_URL']
        builder.use Faraday::Response::RaiseError
        builder.use Faraday::Request::UrlEncoded
        builder.use Faraday::Adapter::NetHttp
      end

      words.each do |word|
        feedlink = Addressable::URI.parse 'http://www.pixiv.net/search.php'
        feedlink.query_values = {
          s_mode: :s_tag,
          word: word,
        }
        feeds = []
        fetcher.search_by_tag word do |user, title, thumb, link, pubdate|
          feeds << to_feed(feedlink, "PxFeed - #{word}", user, title, thumb, link, pubdate)
        end
        if options[:dry_run]
          puts feeds
        else
          fl.post '/rpc/update_feeds', feeds: feeds.to_json, api_key: api_key
        end
      end

      logged_in = false

      user_ids.each do |user_id|
        feedlink = Addressable::URI.parse('http://www.pixiv.net/bookmark.php')
        feedlink.query_values = { id: user_id }
        feeds = []
        if not logged_in
          fetcher.login(pixiv_username, pixiv_password)
          logged_in = true
        end
        fetcher.user_bookmarks(user_id) do |user, title, thumb, link, pubdate|
          feeds << to_feed(feedlink, "PxFeed - Bookmarks by #{user_id}", user, title, thumb, link, pubdate)
        end
        if options[:dry_run]
          puts feeds
        else
          fl.post '/rpc/update_feeds', feeds: feeds.to_json, api_key: api_key
        end
      end

      if options[:bookmark]
        feedlink = 'http://www.pixiv.net/bookmark_new_illust.php'
        feeds = []
        if not logged_in
          fetcher.login(pixiv_username, pixiv_password)
          logged_in = true
        end
        fetcher.bookmark_new_illust do |user, title, thumb, link, pubdate|
          feeds << to_feed(feedlink, 'PxFeed - bookmark new illust', user, title, thumb, link, pubdate)
        end
        if options[:dry_run]
          puts feeds
          puts "#{feeds.to_json.bytesize} bytes"
        else
          fl.post '/rpc/update_feeds', feeds: feeds.to_json, api_key: api_key
        end
      end
    end

    private

    def to_feed(feedlink, feedtitle, user, title, thumb, link, pubdate)
      {
        feedtitle: feedtitle,
        feedlink: feedlink.to_s,
        title: title,
        link: link,
        body: %Q{<img src="#{replace_host(thumb)}"/>},
        author: user,
        category: 'PxFeed',
        published_date: pubdate,
      }
    end

    def replace_host(image_url)
      if ENV['REPLACE_URL']
        uri = Addressable::URI.parse(image_url)
        replace_uri = Addressable::URI.parse(ENV['REPLACE_URL'])
        uri.host = replace_uri.host
        uri.scheme = replace_uri.scheme
        uri.to_s
      else
        image_url
      end
    end
  end
end
