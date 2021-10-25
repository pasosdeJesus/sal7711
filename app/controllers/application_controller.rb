class ApplicationController < Sip::ApplicationController
  protect_from_forgery with: :exception

  # Sin definir control de acceso por ser utilidad
end
