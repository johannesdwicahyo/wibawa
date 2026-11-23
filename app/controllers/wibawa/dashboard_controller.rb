module Wibawa
  class DashboardController < ApplicationController
    def show
      @dashboard = Wibawa.registry.dashboard
    end
  end
end
