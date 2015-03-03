#!/usr/bin/env ruby
require 'cgi'
require 'json'
require 'yaml'
require 'twitter'

twitter = Twitter::REST::Client.new do |config|
  config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

def user_url(screen_name)
  "https://twitter.com/#{screen_name}"
end

def hashtag_url(hashtag)
  "https://twitter.com/search?q=#{CGI.escape("##{hashtag}")}&src=hash"
end

def status_url(tweet)
  "https://twitter.com/#{tweet.user.screen_name}/status/#{tweet.id}"
end

def to_feed(tweet)
  text = tweet.text.dup
  tweet.media.each do |media|
    text.gsub!(media.url, %Q!<a href="#{media.media_url_https}"><img alt="#{media.media_url_https}" src="#{media.media_url_https}"/></a>!)
  end
  tweet.urls.each do |url|
    text.gsub!(url.url, %Q!<a href="#{url.expanded_url}">#{url.expanded_url}</a>!)
  end
  tweet.user_mentions.each do |mention|
    text.gsub!("@#{mention.screen_name}", %Q!<a href="#{user_url mention.screen_name}">@#{mention.screen_name}</a>!)
  end
  tweet.hashtags.each do |hashtag|
    text.gsub!("##{hashtag.text}", %Q!<a href="#{hashtag_url hashtag.text}">##{hashtag.text}</a>!)
  end

  {
    feedtitle: "Twitter - #{tweet.user.screen_name}",
    feedlink: user_url(tweet.user.screen_name),
    title: tweet.text,
    link: status_url(tweet),
    body: text,
    author: tweet.user.screen_name,
    category: 'twitter',
    published_date: tweet.created_at,
  }
end

fl = Faraday::Connection.new do |builder|
  builder.url_prefix = ENV['FASTLADDER_URL']
  builder.use Faraday::Response::RaiseError
  builder.use Faraday::Request::UrlEncoded
  builder.adapter Faraday.default_adapter
end

api_key = ENV['FASTLADDER_API_KEY']
users = ENV['TWITTER_USERS'].split(',').map(&:strip)

users.each do |user|
  begin
    feeds = twitter.user_timeline(user, include_entities: true, count: 200).map { |tweet| to_feed(tweet) }
    fl.post('/rpc/update_feeds', feeds: feeds.to_json, api_key: api_key)
  rescue Twitter::Error => e
    $stderr.puts "#{user}: #{e.class}: #{e.message}"
  end
end
