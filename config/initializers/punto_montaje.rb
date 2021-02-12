Sal7711::Application.config.relative_url_root = ENV.fetch(
  'RUTA_RELATIVA', '/sal7711')
Sal7711::Application.config.assets.prefix = ENV.fetch(
  'RUTA_RELATIVA', '/sal7711') + '/assets'
