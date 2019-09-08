require "crirc"
require "redis"
require "./state"
require "./plugin"

class Client
  @chans : Array(String)

  def initialize(@plugins = [] of Plugin, @chans = ["#arch-fr-free"])
  end

  def start
    irc = Crirc::Network::Client.new ip: "chat.freenode.net",
      nick: "koukoubot", realname: "test bot",
      port: 7000, ssl: true
    irc.connect
    irc.start do |c|
      st = State.new irc: c, chans: @chans
      @plugins.each { |p| p.register(st) } # register plugins
      st.run
      st.close
    end
  end
end

def main
  c = Client.new(plugins: Plugins.all, chans: ["#test1234"])
  c.start
  puts "main exit"
end

main

