source 'https://rubygems.org'


gem 'bcrypt'

gem 'bootsnap', '>=1.1.0', require: false

gem 'bigdecimal'

gem 'cancancan'

gem 'chosen-rails', git: 'https://github.com/vtamara/chosen-rails.git', branch: 'several-fixes' # Cuadros de selección para búsquedas

gem 'coffee-rails' , '>= 5.0.0' # CoffeeScript para recuersos .js.coffee y vistas

gem 'devise' , '>= 4.7.2' # Autenticación 

gem 'devise-i18n', '>= 1.9.2'

gem 'jbuilder' # API JSON facil. Ver: https://github.com/rails/jbuilder

gem 'lazybox' # Dialogo modal

gem 'paperclip' # Maneja adjuntos

gem 'pg' #PostgreSQL

gem 'prawn' # Para generar PDF

gem 'puma', '>= 4.3.3'

gem 'rails', '~> 6.0.3.3'

gem 'rails-i18n', '>= 6.0.0'

gem 'sassc-rails' , '>= 2.1.2' # Para generar CSS

gem 'simple_form' , '>= 5.0.2' # Formularios simples 

gem 'twitter_cldr' # ICU con CLDR

gem 'tzinfo' # Zonas horarias

gem 'webpacker', '>= 5.2.1'

gem 'will_paginate' # Listados en páginas


#####
# Motores que se sobrecargan vistas (deben ponerse en orden de apilamiento 
# lógico y no alfabetico como las gemas anteriores) 

gem 'sip', # Motor generico
  git: 'https://github.com/pasosdeJesus/sip.git'
  #path: '../sip'

gem 'sal7711_gen', # Motor de archivo de prensa
  git: 'https://github.com/pasosdeJesus/sal7711_gen.git'
  #path: '../sal7711_gen'


group :development, :test do

  #gem 'byebug'

  gem 'colorize'

end


group :development do

  gem 'web-console' , '>= 4.0.4' # Consola irb en páginas 

end

group :test do
 
  gem 'capybara' # Pruebas de regresión que no requieren javascript
 
  gem 'meta_request', '>= 0.7.2'

  gem 'rails-controller-testing', '>= 1.0.5'

  gem 'simplecov' 

  gem 'spring' # Acelera ejecutando en fondo.  

end


group :production do
  
  gem 'unicorn' # Para despliegue

end
