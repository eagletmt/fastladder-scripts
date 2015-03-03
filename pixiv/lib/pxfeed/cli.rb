require 'addressable/uri'
require 'faraday'
require 'json'
require 'thor'

require 'pxfeed/fetcher'
require 'pxfeed/version'

module PxFeed
  class CLI < Thor
    class_option :dry_run,
      desc: "Dry run - don't post to Fastladder",
      type: :boolean,
      aliases: %w[-n]

    desc 'bookmark', 'Post bookmark new illusts to Fastladder'
    def bookmark
      feedlink = 'http://www.pixiv.net/bookmark_new_illust.php'
      feeds = []
      fetcher = PxFeed::Fetcher.new
      pixiv_login(fetcher)
      fetcher.bookmark_new_illust do |user, title, thumb, link, pubdate|
        feeds << to_feed(feedlink, 'PxFeed - bookmark new illust', user, title, thumb, link, pubdate)
      end
      post_to_fastladder(feeds)
    end

    desc 'word WORD ...', 'Post search results by word to Fastladder'
    def word(*words)
      fetcher = PxFeed::Fetcher.new
      words.each do |word|
        feedlink = Addressable::URI.parse('http://www.pixiv.net/search.php')
        feedlink.query_values = {
          s_mode: :s_tag,
          word: word,
        }
        feeds = []
        fetcher.search_by_tag word do |user, title, thumb, link, pubdate|
          feeds << to_feed(feedlink, "PxFeed - #{word}", user, title, thumb, link, pubdate)
        end
        post_to_fastladder(feeds)
      end
    end

    desc 'user USER_ID ...', "Post users' bookmarked illusts to Fastladder"
    def user(*user_ids)
      fetcher = PxFeed::Fetcher.new
      pixiv_login(fetcher)
      user_ids.each do |user_id|
        user_id = user_id.to_i
        feedlink = Addressable::URI.parse('http://www.pixiv.net/bookmark.php')
        feedlink.query_values = { id: user_id }
        feeds = []
        fetcher.user_bookmarks(user_id) do |user, title, thumb, link, pubdate|
          feeds << to_feed(feedlink, "PxFeed - Bookmarks by #{user_id}", user, title, thumb, link, pubdate)
        end
        post_to_fastladder(feeds)
      end
    end

    private

    def pixiv_login(fetcher)
      fetcher.login(ENV['PIXIV_USERNAME'], ENV['PIXIV_PASSWORD'])
    end

    def fastladder
      @fastladder ||= Faraday::Connection.new do |builder|
        builder.url_prefix = ENV['FASTLADDER_URL']
        builder.use Faraday::Response::RaiseError
        builder.use Faraday::Request::UrlEncoded
        builder.use Faraday::Adapter::NetHttp
      end
    end

    def post_to_fastladder(feeds)
      if options[:dry_run]
        puts feeds
      else
        api_key = ENV['FASTLADDER_API_KEY']

        fastladder.post('/rpc/update_feeds', feeds: feeds.to_json, api_key: api_key)
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
