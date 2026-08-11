require 'httparty'
require 'nokogiri'
require 'csv' 
require 'json'

# --- SCRAPER 1: TÍA ---
url_tia = "https://www.tia.com.ec/electrodomesticos/electromayores"

headers_tia = {
  "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
}

response_tia = HTTParty.get(url_tia, headers: headers_tia)
doc = Nokogiri::HTML(response_tia.body)

nombre_archivo_tia = "productos_tia_menor_400.csv"

CSV.open(nombre_archivo_tia, "w", write_headers: true, headers: ["Producto", "Precio ($)"]) do |csv|
  puts "Buscando productos menores a $400 en Tía..."

  doc.css('.product-item-details').each do |item|
    titulo_nodo = item.at_css('.product-item-link')
    titulo = titulo_nodo ? titulo_nodo.text.strip : "Sin título"
    
    precio_nodo = item.at_css('.price-box-normal .price')
    
    if precio_nodo
      precio_texto = precio_nodo.text.strip
      precio_numero = precio_texto.gsub('$', '').gsub(',', '.').to_f
      
      if precio_numero > 0 && precio_numero < 400.00
        puts "Guardando en CSV: #{titulo} - $#{precio_numero}"
        csv << [titulo, precio_numero]
      end
    end
  end
end

# --- SCRAPER 2: CASA DEL LIBRO ---
url = "https://www.casadellibro.com/libros/literatura/121000000?json=true"

headers = {
  "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  "Accept" => "application/json"
}

puts "Consultando la categoría Literatura de Casa del Libro..."
response = HTTParty.get(url, headers: headers)

if response.success?
  datos = JSON.parse(response.body)
  nombre_archivo = "literatura_menor_40.csv"
  
  def buscar_productos(nodo, productos_encontrados)
    if nodo.is_a?(Hash)
      # Si el bloque tiene 'seoCurrentPrice' o un bloque 'productoGa' con 'nombre', es un libro
      if nodo.key?('seoCurrentPrice') || (nodo.key?('productoGa') && nodo['productoGa'].key?('nombre'))
        productos_encontrados << nodo
      else
        nodo.values.each { |valor| buscar_productos(valor, productos_encontrados) }
      end
    elsif nodo.is_a?(Array)
      nodo.each { |elemento| buscar_productos(elemento, productos_encontrados) }
    end
  end

  productos = []
  buscar_productos(datos, productos)

  if productos.empty?
    puts "La API respondió, pero aún no encontramos los productos. Revisa la estructura."
  else
    puts "Se encontraron #{productos.length} posibles productos. Filtrando..."
    
    CSV.open(nombre_archivo, "w", write_headers: true, headers: ["Libro", "Precio (€)", "Opiniones"]) do |csv|
      libros_procesados = []

      productos.each do |libro|
        titulo = "Sin título"
        if libro['productoGa'] && libro['productoGa']['nombre']
          titulo = libro['productoGa']['nombre']
        elsif libro['link'] && libro['link']['name']
          titulo = libro['link']['name']
        end
        
        next if libros_procesados.include?(titulo)
        
        precio_texto = libro['seoCurrentPrice'] || libro['seoPrice'] || "0"
        precio_numero = precio_texto.gsub(/[^\d,.]/, '').tr(',', '.').to_f

        total_opiniones = 0
        if libro['reviews'] && libro['reviews'].is_a?(Hash)
          total_opiniones = libro['reviews']['totalReviews'] || 0
        end

        if precio_numero > 0 && precio_numero < 40.00
          libros_procesados << titulo
          puts "Guardando: #{titulo} - #{precio_numero}€ (Opiniones: #{total_opiniones})"
          csv << [titulo, precio_numero, total_opiniones]
        end
      end
    end
    
    puts "\n¡Extracción finalizada con éxito! Archivo generado: #{nombre_archivo}"
  end
else
  puts "Hubo un error al conectar. Código HTTP: #{response.code}"
end
url = "https://www.bosque.com.ec/comedores?__pickRuntime=appsEtag%2Cblocks%2CblocksTree%2Ccomponents%2CcontentMap%2Cextensions%2Cmessages%2Cpage%2Cpages%2Cquery%2CqueryData%2Croute%2CruntimeMeta%2Csettings&__device=tablet"

headers = {
  "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "Accept" => "application/json"
}

puts "Consultando la API interna de El Bosque (Comedores)..."
response = HTTParty.get(url, headers: headers)

if response.success?
  datos = JSON.parse(response.body)
  nombre_archivo = "comedores_el_bosque_mayor_100.csv"
  
  def buscar_productos(nodo, productos_encontrados)
    # Si el nodo es un texto y parece un JSON (comienza con { o [), lo abrimos
    if nodo.is_a?(String) && (nodo.strip.start_with?('{') || nodo.strip.start_with?('['))
      begin
        json_oculto = JSON.parse(nodo)
        buscar_productos(json_oculto, productos_encontrados)
      rescue JSON::ParserError
        # Si falla, no era un JSON válido, lo ignoramos y seguimos
      end
    elsif nodo.is_a?(Hash)
      # Si tiene el título y el rango de precios de VTEX, es nuestro mueble
      if nodo.key?('productName') && nodo.key?('priceRange')
        productos_encontrados << nodo
      else
        nodo.values.each { |valor| buscar_productos(valor, productos_encontrados) }
      end
    elsif nodo.is_a?(Array)
      nodo.each { |elemento| buscar_productos(elemento, productos_encontrados) }
    end
  end

  productos = []
  buscar_productos(datos, productos)

  if productos.empty?
    puts "No se encontraron productos. La estructura de la API sigue siendo inaccesible."
  else
    puts "Se desempaquetaron #{productos.length} posibles muebles. Filtrando los > $100..."
    
    CSV.open(nombre_archivo, "w", write_headers: true, headers: ["Comedor", "Precio ($)"]) do |csv|
      muebles_procesados = []

      productos.each do |mueble|
        titulo = mueble['productName'] || "Sin título"
        
        next if muebles_procesados.include?(titulo)
        
        precio_numero = 0.0

        # Navegamos la estructura de precio que descubriste
        if mueble['priceRange'] && mueble['priceRange']['sellingPrice'] && mueble['priceRange']['sellingPrice']['lowPrice']
          precio_numero = mueble['priceRange']['sellingPrice']['lowPrice'].to_f
        end

        if precio_numero > 100.00
          muebles_procesados << titulo
          puts "Guardando: #{titulo} - $#{precio_numero}"
          csv << [titulo, precio_numero]
        end
      end
    end
    
    puts "\n¡Extracción finalizada con éxito! Archivo generado: #{nombre_archivo}"
  end
else
  puts "Hubo un error al conectar. Código HTTP: #{response.code}"
end