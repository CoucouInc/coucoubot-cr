
require "uri"
require "http"
require "http/client"
require "openssl"
require "xml"
require "./state"

# TODO: contribute upstream
require "./crog" # for parsing youtube metadata

abstract class Plugin
  # Register to the given state's client
  abstract def register(st : State)
end

private def k_coucou(nick : String) : String
  "coucou:#{nick}"
end

class CoucouPlugin < Plugin
  def register(st : State)
    c = st.irc

    # print count for user
    c.on("PRIVMSG", message: /^#{st.prefix}coucou[ ]*$/) do |msg, _|
      nick = extract_nick(msg.source)
      case n = st.redis.get(k_coucou(nick))
      when .nil?
        c.reply msg, "#{nick} never coucouted, sorry :("
      when Int32 | String
        STDERR.puts "current coucou count for #{nick}: #{n}"
        c.reply msg, "#{nick} coucouted #{n} times, wow" 
      else
        STDERR.puts "unexpected value for coucou key: #{n} : #{n.class}"
      end
    end

    # update count
    c.on("PRIVMSG") do |msg, _|
      nick = extract_nick(msg.source)
      text = msg.message || next
      next if /^#{st.prefix}coucou/ =~ text # see previous command
      if md = /\bcoucou\b/.match(text)
        STDERR.puts "detected #{md.size} coucous from #{nick}"
        st.redis.incrby(k_coucou(nick), md.size)
      end
    end
  end
end

class AdminPlugin < Plugin
  def register(st : State)
    admin = "companion_cube"
    c = st.irc

    c.on("PRIVMSG", message: /^#{st.prefix}join .*[ ]*$/) do |msg, _|
      if extract_nick(msg.source) == admin
        text = msg.message || next
        md = /^#{st.prefix}join (.*) *$/.match(text) || next
        chan = Chan.new(md[1]) # extract name of chan
        STDERR.puts "joining chan #{ chan }"
        c.join chan
      end
    end

    c.on("PRIVMSG", message: /^#{st.prefix}part .*[ ]*$/) do |msg, _|
      if extract_nick(msg.source) == admin
        text = msg.message || next
        md = /^#{st.prefix}part (.*) *$/.match(text) || next
        chan = Chan.new(md[1]) # extract name of chan
        STDERR.puts "part chan #{ chan }"
        c.part chan
      end
    end
  end
end

class YTPlugin < Plugin
  def register(st : State)
    st.irc.on("PRIVMSG", message: /^#{st.prefix}yt_search .*$/) do |msg,_|
      text = msg.message || next
      md = /^#{st.prefix}yt_search (.*) *$/.match(text) || next
      query = md[1]

      STDERR.puts "got yt search #{ query }"

      spawn do
        uri = URI.parse "https://www.youtube.com/results"
        params = HTTP::Params.build do |b|
          #b.add "sp", "EgIQAQ%3D%3D"
          #b.add "q", query
          b.add "search_query", query
        end
        uri.query = params
        uri = uri.to_s

        STDERR.puts "got yt search #{ query }, use uri #{ uri }"

        begin
          content = HTTP::Client.get(uri, tls: OpenSSL::SSL::Context::Client.insecure).body
          #meta = Crog::Parse.new(uri, tls: OpenSSL::SSL::Context::Client.insecure)
          xml = XML.parse_html(content)
          n = xml.xpath_node(%(//a[@id='video-title']))
          if n.nil?
            STDERR.puts "cannot find any video"
            next
          end

          STDERR.puts "node: #{ n.inspect }"
          title = n["title"]
          url = %(https://youtube.com/#{ n["href"].not_nil! })

          st.irc.reply msg, "#{url} #{ title }"
        rescue e
          #STDERR.puts "content: #{ content.inspect }"
          STDERR.puts "couldn't obtain metadata for #{ uri.to_s }: ", e
        end
      end
    end

  end
end

module Plugins
  # all plugins
  def self.all
    [
      CoucouPlugin.new,
      AdminPlugin.new,
      YTPlugin.new,
    ].as(Array(Plugin))
  end
end
