require 'json'
require 'optparse'

require 'addressable/uri'
require 'faraday'

require 'pxfeed/fetcher'
require 'pxfeed/version'

module PxFeed
  class CLI
    def start(argv)
      opts = {
        bookmark: false,
        pixiv_username: nil,
        pixiv_password: nil,
        dry_run: false,
      }
      words = []
      user_ids = []
      OptionParser.new.tap do |parser|
        parser.version = PxFeed::VERSION

        parser.on('-w FILE', 'Path to the file containing words') do |v|
          open(v) do |f|
            f.each_line do |word|
              words << word.chomp
            end
          end
        end

        parser.on('-b', '--bookmark', 'Enable bookmark_new_illust') do
          opts[:bookmark] = true
          opts[:pixiv_username] ||= ENV['PIXIV_USERNAME']
          opts[:pixiv_password] ||= ENV['PIXIV_PASSWRD']
        end

        parser.on('-n', '--dry-run', "Don't post to Fastladder") do
          opts[:dry_run] = true
        end

        parser.on('-u FILE', 'Path to the file containing user ids') do |v|
          opts[:pixiv_username] ||= ENV['PIXIV_USERNAME']
          opts[:pixiv_password] ||= ENV['PIXIV_PASSWRD']
          open(v) do |f|
            f.each_line do |user_id|
              user_ids << user_id.chomp.to_i
            end
          end
        end
      end.parse! argv
      words += argv

      api_key = ENV['FASTLADDER_API_KEY']
      base_uri = ENV['FASTLADDER_URL']

      fetcher = PxFeed::Fetcher.new
      fl = Faraday::Connection.new do |builder|
        builder.url_prefix = base_uri
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
        if opts[:dry_run]
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
          fetcher.login(opts[:pixiv_username], opts[:pixiv_password])
          logged_in = true
        end
        fetcher.user_bookmarks(user_id) do |user, title, thumb, link, pubdate|
          feeds << to_feed(feedlink, "PxFeed - Bookmarks by #{user_id}", user, title, thumb, link, pubdate)
        end
        if opts[:dry_run]
          puts feeds
        else
          fl.post '/rpc/update_feeds', feeds: feeds.to_json, api_key: api_key
        end
      end

      if opts[:bookmark]
        feedlink = 'http://www.pixiv.net/bookmark_new_illust.php'
        feeds = []
        if not logged_in
          fetcher.login(opts[:pixiv_username], opts[:pixiv_password])
          logged_in = true
        end
        fetcher.bookmark_new_illust do |user, title, thumb, link, pubdate|
          feeds << to_feed(feedlink, 'PxFeed - bookmark new illust', user, title, thumb, link, pubdate)
        end
        if opts[:dry_run]
          puts feeds
          puts "#{feeds.to_json.bytesize} bytes"
        else
          fl.post '/rpc/update_feeds', feeds: feeds.to_json, api_key: api_key
        end
      end
    end

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
