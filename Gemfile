source 'https://rubygems.org'


gem 'babel-transpiler'

gem 'bcrypt'

gem 'bootsnap', '>=1.1.0', require: false

gem 'bigdecimal'

gem 'cancancan'

gem 'chosen-rails', git: 'https://github.com/vtamara/chosen-rails.git', branch: 'several-fixes' # Cuadros de selección para búsquedas

gem 'cocoon', git: 'https://github.com/vtamara/cocoon.git', 
  branch: 'new_id_with_ajax'# Formularios anidados (algunos con ajax)

gem 'coffee-rails' # CoffeeScript para recuersos .js.coffee y vistas

gem 'devise' # Autenticación 

gem 'devise-i18n'

gem 'jbuilder' # API JSON facil. Ver: https://github.com/rails/jbuilder

gem 'jsbundling-rails'

gem 'kt-paperclip',                 # Anexos
  git: 'https://github.com/kreeti/kt-paperclip.git'

gem 'lazybox' # Dialogo modal

gem 'nokogiri', '>=1.11.1'

gem 'pg' #PostgreSQL

gem 'prawn' # Para generar PDF

gem 'rails', '~> 7.0'

gem 'rails-i18n'

gem 'sassc-rails' # Para generar CSS

gem 'simple_form' # Formularios simples 

gem 'sprockets-rails'

gem 'stimulus-rails'

gem 'turbo-rails', '~> 1.0'

gem 'twitter_cldr' # ICU con CLDR

gem 'tzinfo' # Zonas horarias

gem 'will_paginate' # Listados en páginas


#####
# Motores que se sobrecargan vistas (deben ponerse en orden de apilamiento 
# lógico y no alfabetico como las gemas anteriores) 

gem 'msip', # Motor generico
  git: 'https://gitlab.com/pasosdeJesus/msip.git', branch: 'main'
  #path: '../msip'

gem 'sal7711_gen', # Motor de archivo de prensa
  git: 'https://gitlab.com/pasosdeJesus/sal7711_gen.git', branch: 'main'
  #path: '../sal7711_gen'


group :development, :test do

  gem 'debug'

  gem 'colorize'

  gem 'dotenv-rails'
end


group :development do

  gem 'puma', '>= 4.3.3'

  gem 'web-console' # Consola irb en páginas 

end

group :test do
  gem 'cuprite'

  gem 'capybara' # Pruebas de regresión que no requieren javascript
 
  gem 'rails-controller-testing'

  gem 'simplecov'

  gem 'spring' # Acelera ejecutando en fondo.  
end


group :production do
  
  gem 'unicorn' # Para despliegue

end
