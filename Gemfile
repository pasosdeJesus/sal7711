source 'https://rubygems.org'


gem 'bcrypt'

gem 'bootsnap', '>=1.1.0', require: false

gem 'bigdecimal'

gem 'cancancan'

gem 'chosen-rails', git: 'https://github.com/vtamara/chosen-rails.git', branch: 'several-fixes' # Cuadros de selección para búsquedas

gem 'coffee-rails' # CoffeeScript para recuersos .js.coffee y vistas

gem 'devise' # Autenticación 

gem 'devise-i18n'

gem 'jbuilder' # API JSON facil. Ver: https://github.com/rails/jbuilder

gem 'lazybox' # Dialogo modal

gem 'paperclip' # Maneja adjuntos

gem 'pg' #PostgreSQL

gem 'prawn' # Para generar PDF

gem 'puma'

gem 'rails', '~> 6.0.0.rc1'

gem 'rails-i18n'

gem 'sassc-rails' # Para generar CSS

gem 'simple_form' # Formularios simples 

gem 'twitter_cldr' # ICU con CLDR

gem 'tzinfo' # Zonas horarias

gem 'webpacker'

gem 'will_paginate' # Listados en páginas


#####
# Motores que se sobrecargan vistas (deben ponerse en orden de apilamiento 
# lógico y no alfabetico como las gemas anteriores) 

gem 'sip', # Motor generico
  git: 'https://github.com/pasosdeJesus/sip.git', branch: :bs4
  #path: '../sip'

gem 'sal7711_gen', # Motor de archivo de prensa
  git: 'https://github.com/pasosdeJesus/sal7711_gen.git', branch: :bs4
  #path: '../sal7711_gen'


group :development, :test do

  #gem 'byebug'

  gem 'colorize'

end


group :development do

  gem 'web-console' # Consola irb en páginas 

end

group :test do
 
  gem 'capybara' # Pruebas de regresión que no requieren javascript
 
  gem 'meta_request'

  gem 'rails-controller-testing'

  gem 'simplecov' 

  gem 'spring' # Acelera ejecutando en fondo.  

end


group :production do
  
  gem 'unicorn' # Para despliegue

end
