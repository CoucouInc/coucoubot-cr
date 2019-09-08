require "crirc"
require "redis"

alias CClient = Crirc::Controller::Client
alias Chan = Crirc::Protocol::Chan

def extract_nick(address : String)
  address.split('!')[0]
end

class State
  @redis : Redis::PooledClient
  property redis
  @irc : CClient
  property irc
  @prefix: String
  property prefix

  def initialize(irc : CClient, prefix = ">", @chans = [] of String)
    @irc = irc
    @prefix = prefix
    @redis = Redis::PooledClient.new || raise("could not connect to redis")
  end

  # main loop
  def run
    @irc.on_ready do
      irc.on("PING") do |msg|
        STDERR.puts "reply to ping"
        irc.pong(msg.message)
      end
      # join all the required chans
      @chans.each do |cname|
        chan = Chan.new(cname)
        puts "try to join #{ chan.inspect }"
        @irc.join chan
      end
    end
    loop do
      msg = @irc.gets()
      break if msg.nil?
      spawn { @irc.handle(msg.as(String)) }
      STDERR.puts "received #{ msg.inspect }"
    rescue e
      puts "error #{ e }"
    end
  end

  def close
    @redis.close
  end
end
