require 'httparty'
require 'nokogiri'

url = "https://books.toscrape.com"
response = HTTParty.get(url)
doc = Nokogiri::HTML(response.body)

doc.css("article.product_pod").each do |libro|
  titulo = libro.css("h3 a").attr("title").value
  precio = libro.css(".price_color").text
  puts "#{titulo} - #{precio}"
end