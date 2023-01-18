require 'test_helper'

module Msip
  class TsitioTest < ActiveSupport::TestCase

    test "busca existente" do
      tsitio = Msip::Tsitio.where(id: 2).take
      assert_equal('URBANO', tsitio.nombre)
    end

    test "crea no valido" do
      tsitio = Msip::Tsitio.new(fechacreacion: "2015-07-23") # sin nombre
      assert_not tsitio.save
    end

    test "crea valido" do
      tsitio = Msip::Tsitio.new(id:1000, nombre: "x", fechacreacion: "2015-07-23")
      assert tsitio.save
      tsitio.destroy!
    end

  end
end
