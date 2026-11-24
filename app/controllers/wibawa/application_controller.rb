module Wibawa
  class ApplicationController < Wibawa.config.parent_controller.constantize
    include Wibawa::ResourceAccess

    layout "wibawa/application"

    protect_from_forgery with: :exception

    before_action :wibawa_authenticate!

    helper Wibawa::ApplicationHelper
    helper_method :wibawa_current_user, :wibawa_authorized?, :wibawa_presenter

    rescue_from Wibawa::ResourceNotFound, ActiveRecord::RecordNotFound do
      render "wibawa/errors/not_found", status: :not_found
    end

    rescue_from Wibawa::NotAuthorized do
      if request.get? && !request.format.csv?
        render "wibawa/errors/forbidden", status: :forbidden
      else
        redirect_back_or_to root_path, alert: t("wibawa.flash.not_authorized"), status: :see_other
      end
    end

    private

    def wibawa_authenticate!
      block = Wibawa.config.authenticate
      instance_exec(&block) if block
    end

    def wibawa_current_user
      return @wibawa_current_user if defined?(@wibawa_current_user)

      setting = Wibawa.config.current_user
      @wibawa_current_user =
        case setting
        when Proc then instance_exec(&setting)
        when Symbol, String then respond_to?(setting, true) ? send(setting) : nil
        end
    end
  end
end
