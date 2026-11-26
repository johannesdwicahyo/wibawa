module Wibawa
  class ApplicationController < Wibawa.config.parent_controller.constantize
    include Wibawa::ResourceAccess

    layout "wibawa/application"

    protect_from_forgery with: :exception
    cattr_accessor :wibawa_no_user_warned, default: false

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
      gate = Wibawa.config.authenticate
      return instance_exec(&gate) if gate.is_a?(Proc)
      return if gate || Rails.env.local? # guarded elsewhere, or development and test

      logger&.error("Wibawa refused a request: config.authenticate_with is not set (config/initializers/wibawa.rb).")
      render plain: "This admin is not set up yet: config.authenticate_with is missing. " \
                    "See config/initializers/wibawa.rb.", status: :forbidden
    end

    def wibawa_current_user
      return @wibawa_current_user if defined?(@wibawa_current_user)

      setting = Wibawa.config.current_user
      @wibawa_current_user =
        case setting
        when Proc then instance_exec(&setting)
        when Symbol, String then respond_to?(setting, true) ? send(setting) : warn_no_current_user(setting)
        end
    end

    # An app that signs people in but has no method by that name (the Rails 8
    # authentication generator uses Current.user) would otherwise run with no
    # user and no hint why: authorization sees nil, saved views are shared by
    # everyone and the audit log names nobody. Said once; an admin with no
    # sign-in at all has no user to find, so it is left in peace.
    def warn_no_current_user(name)
      return nil if !Wibawa.config.authenticate.is_a?(Proc) || self.class.wibawa_no_user_warned

      self.class.wibawa_no_user_warned = true
      logger&.warn("Wibawa: config.current_user is :#{name}, but #{Wibawa.config.parent_controller} has no such method, so the admin sees no " \
                   "signed-in user. Set it in config/initializers/wibawa.rb, e.g. config.current_user = -> { Current.user }.")
      nil
    end
  end
end
