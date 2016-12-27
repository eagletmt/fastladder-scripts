require 'date'
require 'faraday'
require 'nokogiri'
require 'json'

require 'faraday/cookie_jar'

module PxFeed
  class Fetcher
    class NotLoggedIn < StandardError; end
    class LoginFailure < StandardError; end

    def initialize(conn = nil)
      @conn ||= Faraday::Connection.new do |builder|
        builder.url_prefix = 'http://www.pixiv.net/'
        builder.use Faraday::Response::RaiseError
        builder.use Faraday::Request::UrlEncoded
        builder.use Faraday::CookieJar
        builder.adapter Faraday.default_adapter
      end
    end

    def search_by_tag(word, &blk)
      res = @conn.get '/search.php', s_mode: 's_tag', word: word
      each_image_item res.body, &blk
    end

    def user_bookmarks(user_id, &blk)
      res = @conn.get('/bookmark.php', id: user_id)
      Nokogiri::HTML.parse(res.body).tap do |doc|
        doc.css('.image-item').each do |li|
          a = li.at_css('.work')
          if a.nil?
            $stderr.puts "http://pixiv.net/bookmark.php?id=#{user_id} has li without .work. Maybe it has been deleted."
            next
          end
          title = a.inner_text
          thumb = a.at_css('img')['data-src']
          link = @conn.url_prefix + a['href']
          pubdate = extract_pubdate(thumb)
          user = li.at_css('.user').inner_text
          blk.call(user, title, thumb, link.to_s, pubdate)
        end
      end
    end

    def bookmark_new_illust(&blk)
      res = @conn.get "/bookmark_new_illust.php"
      if res.status == 302
        raise NotLoggedIn
      end
      each_image_item res.body, &blk
    end

    def login(user, pass)
      res = @conn.get('https://accounts.pixiv.net/login?lang=ja')
      post_key = Nokogiri::HTML.parse(res.body).at_css('#old-login input[name="post_key"]')['value']
      res = @conn.post('https://accounts.pixiv.net/api/login?lang=ja', pixiv_id: user, password: pass, post_key: post_key)
      if res.status != 200
        raise LoginFailure.new("/api/login returned status #{res.status}")
      end
      j = JSON.parse(res.body)
      if j['error']
        raise LoginFailure.new("/api/login returned error #{j}")
      end
      unless j['body']['successed']
        raise LoginFailure.new("/api/login failed #{j}")
      end
    end

    private

    def extract_pubdate(thumb_url)
      if m = thumb_url.match(%r!/img/(\d{4})/(\d{2})/(\d{2})/(\d{2})/(\d{2})/(\d{2})/!)
        DateTime.new(m[1].to_i, m[2].to_i, m[3].to_i, m[4].to_i, m[5].to_i, m[6].to_i, "+0900").to_time
      else
        $stderr.puts "Unknown pubdate: #{thumb_url}"
        Time.at(0)
      end
    end

    def each_image_item(body, &blk)
      Nokogiri::HTML.parse(body).tap do |doc|
        doc.css('.image-item').each do |li|
          title = li.at_css('.title')['title']
          thumb = li.at_css('._thumbnail')['data-src']
          user = li.at_css('.user')['title']
          link = li.at_css('a.work')['href']
          pubdate = extract_pubdate(thumb)
          blk.call user, title, thumb, (@conn.url_prefix + link).to_s, pubdate
        end
      end
    end
  end
end
