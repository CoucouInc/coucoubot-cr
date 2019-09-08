
require "xml"


def main(file)
  #meta = Crog::Parse.new(uri, tls: OpenSSL::SSL::Context::Client.insecure)
  xml = XML.parse_html(File.read(file))
  puts xml.inspect
  n = xml.xpath_node(%(//a[@id='video-title']))
  if n.nil?
    puts "cannot find any video"
    return
  end

  puts "node: #{ n.inspect }"
  title = n["title"]
  url = %(https://youtube.com/#{ n["href"].not_nil! })

  puts "result: #{url} #{ title }"
end

main "foo.html"
