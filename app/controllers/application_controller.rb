# -*- encoding : utf-8 -*-
require 'factory_girl_rails'

class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :set_fake_env_for_development
  before_filter :set_user
  before_filter :change_language
  before_filter :set_locale
  before_filter :set_university
  before_filter :set_fixed_locale_for_admin_login
  before_filter :init_custom_view_paths

  helper_method :user_role?
  helper_method :is_in_current_university?
  helper_method :can_admin_calls?
  helper_method :can_admin_organs?
  helper_method :can_apply?
  helper_method :not_supported_user

  layout :layout_by_context

  protected

  def user_role?(role)
    return false if not @user
    return false unless is_in_current_university?
    @user.role == role
  end

  def is_in_current_university?
    return false if not @user
    @user.university.key == @university.key
  end

  def can_admin_organs?
    user_role?(:role_university_staff) || user_role?(:role_union_employee)
  end

  def can_admin_calls?
    user_role?(:role_union_employee)
  end

  def can_apply?
    is_in_current_university?
  end

  def authorize_organ_admin
    if not can_admin_organs?
      render text: "Unauthorized", status: :unauthorized
      return false
    end
  end

  def authorize_call_admin
    if not can_admin_calls?
      render text: "Unauthorized", status: :unauthorized
      return false
    end
  end

  def not_supported_user
    return nil if @user
    User.env_to_attributes(request.env).select{|k,v| [:first_name, :last_name, :university_domain].include? k}
  end

  def set_fake_env_for_development
    # In order to run and test authentication in development
    # environment. Add fake Shibboleth variables to request env
    if Rails.env.development? || Rails.env.test?
      test_user = session[:test_user]
      if test_user == "eija"
        FactoryGirl.create :eija
        request.env["A_PRINCIPAL_NAME"] = "eizit@sty.fi"
        request.env["A_GIVEN_NAME"] = "Eija"
        request.env["A_SURNAME"] = "Zitting"
        request.env["A_MOBILE"] = "+358 40 123 1234"
        request.env["A_MAIL"] = "eija.zitting@sty.fi"
        request.env["A_HOME_ORGANIZATION"] = "sty.fi"
      elsif test_user == "aaro"
        FactoryGirl.create :aaro
        request.env["A_PRINCIPAL_NAME"] = "aaroha@sty.fi"
        request.env["A_GIVEN_NAME"] = "Aaro"
        request.env["A_SURNAME"] = "Häkkinen"
        request.env["A_MOBILE"] = "+358 40 123 1234"
        request.env["A_MAIL"] = "aaro.hakkinen@sty.fi"
        request.env["A_HOME_ORGANIZATION"] = "sty.fi"
      elsif test_user == "martti"
        FactoryGirl.create :student_martti
        request.env["A_PRINCIPAL_NAME"] = 'marpul@sty.fi'
        request.env["A_GIVEN_NAME"] = "Martti"
        request.env["A_SURNAME"] = "Pulliainen"
        request.env["A_MOBILE"] = "+358 40 555 4321"
        request.env["A_MAIL"] = "martti@sty.fi"
        request.env["A_HOME_ORGANIZATION"] = "sty.fi"
      elsif test_user == "xerxes"
        FactoryGirl.create :xerxes
        request.env["A_PRINCIPAL_NAME"] = 'xerxes@ay.fi'
        request.env["A_GIVEN_NAME"] = "Xerxes"
        request.env["A_SURNAME"] = "I"
        request.env["A_MOBILE"] = "+358 40 555 7777"
        request.env["A_MAIL"] = "xerxes@ay.fi"
        request.env["A_HOME_ORGANIZATION"] = "ay.fi"
      elsif test_user == "reija"
        request.env["A_PRINCIPAL_NAME"] = 'reija@xx.fi'
        request.env["A_GIVEN_NAME"] = "Reija"
        request.env["A_SURNAME"] = "Rento"
        request.env["A_MOBILE"] = "+358 40 555 8888"
        request.env["A_MAIL"] = "reija@xx.fi"
        request.env["A_HOME_ORGANIZATION"] = "xx.fi"
      end

    end
  end

  def set_user
    @user = User.update_or_create_from_env(request.env) # FactoryGirl.create(:eija)
  end

  def change_language(to_locale=nil)
    to_locale ||= request.query_parameters[:locale]
    return if to_locale.nil?
    return if request.fullpath =~ /\/admin\//
    current_path = Rails.application.routes.recognize_path request.fullpath
    redirect_to current_path.merge(locale: to_locale)
  end

  def set_locale
    locale = params[:locale]
    return if locale.nil?
    change_language(I18n.default_locale) unless Halloped::languages.include?(locale.to_sym)
    I18n.locale = locale
  end

  def set_university
    return if params[:university].nil?
    @university = Organization.roots.where(key: params[:university]).first
    redirect_to(index_path(locale: params[:locale])) if @university.nil?
  end

  def set_fixed_locale_for_admin_login
    I18n.locale = :en if request.fullpath.match /^\/admins\//
  end

  def layout_by_context
    if request.fullpath.match /^\/admins\//
      'device'
    else
      'application'
    end
  end

  def verify_university(organization)
    if @university.key != organization.root.key
      render_404
    end
  end

  def find_organ_from_current_university(symbol=:id)
    @organ = Organ.find(params[symbol])
    verify_university @organ.organization
    @organ
  end

  def find_call_from_current_university(symbol=:id)
    @call = Call.find(params[symbol])
    verify_university @call.organ.organization
    @call
  end

  def render_404
    respond_to do |format|
      format.html { render file: Rails.root.join('public/404.html'), status: :not_found , layout: false}
      format.any  { head :not_found }
    end
  end

  def init_custom_view_paths
    return unless @university
    @custom_root = Rails.root.join('public/universities')
    @custom_path = @custom_root.join(@university.key)
    @custom_public_path = Pathname.new('/').join(@custom_path.relative_path_from(Rails.root.join('public')))
    prepend_view_path @custom_path
    prepend_view_path @custom_root
  end


end
