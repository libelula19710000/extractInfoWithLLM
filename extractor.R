# Cargar la librería 'httr' para hacer solicitudes HTTP
library(httr) 

# Cargar la librería 'jsonlite' para trabajar con datos en formato JSON
library(jsonlite) 

# Cargar la librería 'pdftools' para extraer texto de archivos PDF
library(pdftools) 

# Cargar la librería 'tidyverse' para manipulación de datos, incluyendo 'dplyr' y 'tibble'
library(tidyverse) 

# Definir el directorio donde están almacenados los archivos PDF
directorio <- "data"

# Listar todos los archivos dentro del directorio que contienen "factura" en el nombre
# `pattern = "factura"` filtra los archivos que tienen "factura" en su nombre
# `full.names = TRUE` devuelve la ruta completa de los archivos
archivos_factura <- list.files(path = directorio, pattern = "factura", full.names = TRUE)

# Configuración de la solicitud a la API
# URL base de la API local a la que se va a enviar la solicitud
base_url <- "http://localhost:1234/v1"
# Clave de API necesaria para autenticarse en la API
api_key <- "lm-studio"
# Modelo específico que se va a utilizar en la API para procesar los datos
myModel = "microsoft/Phi-3-mini-4k-instruct-gguf"

# Si se estuviera utilizando la API de OpenAI, se configuraría de la siguiente manera:
# api_key <- "mi API key aquí"  # Clave de API para OpenAI
# base_url = "https://api.openai.com/v1/"  # URL base de la API de OpenAI
# myModel = "gpt-3.5-turbo"  # Modelo de OpenAI que se utilizaría

# Crear un tibble vacío para almacenar los resultados extraídos de cada factura
# Las columnas del tibble son 'Customer', 'Date' y 'Total_Amount', todas de tipo character
resultados <- tibble(Customer = character(), Date = character(), Total_Amount = character())

# Bucle para procesar cada archivo PDF en la lista de archivos de facturas
for (i in 1:length(archivos_factura)) {
  
  # Leer el archivo PDF actual
  pdf_file <- archivos_factura[i]
  
  # Extraer el texto del archivo PDF
  pdf_text <- pdf_text(pdf_file)
  
  # Crear el cuerpo de la solicitud a enviar a la API, con el modelo y el texto extraído del PDF
  # El mensaje del sistema indica al modelo cómo debe procesar el texto y qué datos extraer
  body <- list(
    model = myModel,
    messages = list(
      list(role = "system", content = "You are going to receive an invoice data in text format. Read it and identify the following three fields on the invoice:
1. Customer
2. Date
3. Total amount
Once identified return the three fields separated by commas in the following format:
Customer, Date (DD-MM-YYYYY), Total Amount.
Remember, return only these three items in the format indicated (separated by commas on a single line) and nothing else."),
      list(role = "user", content = pdf_text)
    ),
    temperature = 0.7  # Configuración de temperatura para el modelo (controla la creatividad del modelo)
  )
  
  # Convertir el cuerpo de la solicitud a formato JSON para enviarlo a la API
  body_json <- toJSON(body, auto_unbox = TRUE)
  
  # Enviar la solicitud POST a la API
  # Se incluye la autorización con la clave de API y se especifica que el contenido es JSON
  response <- POST(
    url = paste0(base_url, "/chat/completions"),
    add_headers(Authorization = paste("Bearer", api_key), `Content-Type` = "application/json"),
    body = body_json,
    encode = "raw"
  )
  
  # Procesar la respuesta de la API
  # Obtener el contenido de la respuesta en formato texto y con codificación UTF-8
  response_content <- content(response, "text", encoding = "UTF-8")
  
  # Parsear el contenido de la respuesta JSON a una estructura de R
  parsed_content <- fromJSON(response_content)
  
  # Acceder al contenido del mensaje dentro de la respuesta en `choices` -> `message`
  message_content <- parsed_content$choices$message$content[[1]]
  
  # Separar el contenido del mensaje por comas para extraer 'Customer', 'Date' y 'Total Amount'
  contenido_separado <- str_split(message_content, ",")[[1]]
  
  # Añadir los resultados extraídos al tibble
  resultados <- resultados %>% add_row(
    Customer = trimws(contenido_separado[1]),  # Eliminar espacios en blanco de 'Customer'
    Date = trimws(contenido_separado[2]),      # Eliminar espacios en blanco de 'Date'
    Total_Amount = trimws(contenido_separado[3])  # Eliminar espacios en blanco de 'Total Amount'
  )
}

# Exportar el tibble con los resultados a un archivo CSV
write_csv(resultados, "resultados_facturas.csv")

