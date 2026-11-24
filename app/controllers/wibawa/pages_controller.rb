module Wibawa
  class PagesController < ApplicationController
    before_action :load_page

    helper_method :page

    attr_reader :page

    def show; end

    def run
      action = page.find_action(params[:page_action]) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(action.name, page)
      result = instance_exec(&action.block)
      wibawa_audit(action.name)
      return if performed?

      message = result.is_a?(String) ? result : t("wibawa.flash.action_done", action: action.label)
      redirect_to page_path(page: page.key), notice: message, status: :see_other
    end

    private

    def load_page
      @page = Wibawa.registry.page(params[:page]) || raise(Wibawa::ResourceNotFound)
      wibawa_authorize!(:show, page)
    end

    # What the audit log files a page action under.
    def resource = Struct.new(:key).new("pages/#{page.key}")
  end
end
