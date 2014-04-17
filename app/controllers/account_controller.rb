#-- encoding: UTF-8
#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2014 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require 'concerns/omniauth_login'

class AccountController < ApplicationController
  include CustomFieldsHelper
  include OmniauthLogin

  # prevents login action to be filtered by check_if_login_required application scope filter
  skip_before_filter :check_if_login_required

  # Login request and validation
  def login
    if User.current.logged?
      redirect_to home_url
    elsif request.post?
      authenticate_user
    end
  end

  # Log out current user and redirect to welcome page
  def logout
    logout_user
    redirect_to home_url
  end

  # Enable user to choose a new password
  def lost_password
    redirect_to(home_url) && return unless Setting.lost_password?
    if params[:token]
      @token = Token.find_by_action_and_value("recovery", params[:token].to_s)
      redirect_to(home_url) && return unless @token and !@token.expired?
      @user = @token.user
      if request.post?
        @user.password, @user.password_confirmation = params[:new_password], params[:new_password_confirmation]
        @user.force_password_change = false
        if @user.save
          @token.destroy
          flash[:notice] = l(:notice_account_password_updated)
          redirect_to :action => 'login'
          return
        end
      end
      render :template => "account/password_recovery"
      return
    else
      if request.post?
        user = User.find_by_mail(params[:mail])

        unless user
          # user not found in db
          (flash.now[:error] = l(:notice_account_unknown_email); return)
        end

        unless user.change_password_allowed?
          # user uses an external authentification
          (flash.now[:error] = l(:notice_can_t_change_password); return)
        end

        # create a new token for password recovery
        token = Token.new(:user => user, :action => "recovery")
        if token.save
          UserMailer.password_lost(token).deliver
          flash[:notice] = l(:notice_account_lost_email_sent)
          redirect_to :action => 'login', :back_url => home_url
          return
        end
      end
    end
  end

  # User self-registration
  def register
    redirect_to(home_url) && return unless Setting.self_registration? || session[:auth_source_registration]
    if request.get?
      session[:auth_source_registration] = nil
      @user = User.new(:language => Setting.default_language)
    else
      @user = User.new
      @user.admin = false
      @user.register
      if session[:auth_source_registration]
        # on-the-fly registration via omniauth or via auth source
        if session[:auth_source_registration][:omniauth]
          register_via_omniauth(@user, session, permitted_params)
        else
          register_and_login_via_authsource(@user, session, permitted_params)
        end
      else
        @user.attributes = permitted_params.user
        @user.login = params[:user][:login]
        @user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation]

        register_user_according_to_setting(@user)
      end
    end
  end

  # Token based account activation
  def activate
    redirect_to(home_url) && return unless Setting.self_registration? && params[:token]
    token = Token.find_by_action_and_value('register', params[:token].to_s)
    redirect_to(home_url) && return unless token and !token.expired?
    user = token.user
    redirect_to(home_url) && return unless user.registered?
    user.activate
    if user.save
      token.destroy
      flash[:notice] = l(:notice_account_activated)
    end
    redirect_to :action => 'login'
  end

  # Process a password change form, used when the user is forced
  # to change the password.
  # When making changes here, also check MyController.change_password
  def change_password
    @user = User.find_by_login(params[:username])
    @username = @user.login

    # A JavaScript hides the force_password_change field for external
    # auth sources in the admin UI, so this shouldn't normally happen.
    return if redirect_if_password_change_not_allowed(@user)

    if @user.check_password?(params[:password])
      @user.password = params[:new_password]
      @user.password_confirmation = params[:new_password_confirmation]
      @user.force_password_change = false
      if @user.save

        result = password_authentication(params[:username], params[:new_password])
        # password_authentication resets session including flash notices,
        # so set afterwards.
        flash[:notice] = l(:notice_account_password_updated)
        return result
      end
    else
      invalid_credentials
    end
    render 'my/password'
  end

  private

  def logout_user
    if User.current.logged?
      cookies.delete OpenProject::Configuration['autologin_cookie_name']
      Token.delete_all(["user_id = ? AND action = ?", User.current.id, 'autologin'])
      self.logged_user = nil
    end
  end

  def authenticate_user
    password_authentication(params[:username], params[:password])
  end

  def password_authentication(username, password)
    user = User.try_to_login(username, password)
    if user.nil?
      # login failed, now try to find out why and do the appropriate thing
      user = User.find_by_login(username)
      if user and user.check_password?(password)
        # correct password
        if not user.active?
          return inactive_account if user.registered?
          invalid_credentials
        elsif user.force_password_change
          return if redirect_if_password_change_not_allowed(user)
          render_password_change(I18n.t(:notice_account_new_password_forced))
        elsif user.password_expired?
          return if redirect_if_password_change_not_allowed(user)
          render_password_change(I18n.t(:notice_account_password_expired,
                                        :days => Setting.password_days_valid.to_i))
        else
          invalid_credentials
        end
      else
        # incorrect password
        invalid_credentials
      end
    elsif user.new_record?
      onthefly_creation_failed(user, {:login => user.login, :auth_source_id => user.auth_source_id })
    else
      # Valid user
      successful_authentication(user)
    end
  end

  def successful_authentication(user)
    # Valid user
    self.logged_user = user
    # generate a key and set cookie if autologin
    if params[:autologin] && Setting.autologin?
      set_autologin_cookie(user)
    end
    call_hook(:controller_account_success_authentication_after, {:user => user })

    redirect_after_login(user)
  end

  def set_autologin_cookie(user)
    token = Token.create(:user => user, :action => 'autologin')
    cookie_options = {
      :value => token.value,
      :expires => 1.year.from_now,
      :path => OpenProject::Configuration['autologin_cookie_path'],
      :secure => OpenProject::Configuration['autologin_cookie_secure'],
      :httponly => true
    }
    cookies[OpenProject::Configuration['autologin_cookie_name']] = cookie_options
  end

  def login_user_if_active(user)
    if user.active?
      successful_authentication(user)
    else
      account_pending
    end
  end

  def register_and_login_via_authsource(user, session, permitted_params)
    @user.attributes = permitted_params.user
    @user.activate
    @user.login = session[:auth_source_registration][:login]
    @user.auth_source_id = session[:auth_source_registration][:auth_source_id]

    if @user.save
      session[:auth_source_registration] = nil
      self.logged_user = @user
      flash[:notice] = l(:notice_account_activated)
      redirect_to :controller => '/my', :action => 'account'
    end
    # Otherwise render register view again
  end

  # Onthefly creation failed, display the registration form to fill/fix attributes
  def onthefly_creation_failed(user, auth_source_options = { })
    @user = user
    session[:auth_source_registration] = auth_source_options unless auth_source_options.empty?
    render :action => 'register'
  end

  def invalid_credentials
    logger.warn "Failed login for '#{params[:username]}' from #{request.remote_ip} at #{Time.now.utc}"
    if Setting.brute_force_block_after_failed_logins.to_i == 0
      flash.now[:error] = I18n.t(:notice_account_invalid_credentials)
    else
      flash.now[:error] = I18n.t(:notice_account_invalid_credentials_or_blocked)
    end
  end

  def inactive_account
    logger.warn "Failed login for '#{params[:username]}' from #{request.remote_ip} at #{Time.now.utc} (INACTIVE)"
    flash.now[:error] = l(:notice_account_inactive)
  end

  def redirect_if_password_change_not_allowed(user)
    if user and not user.change_password_allowed?
      logger.warn "Password change for user '#{user}' forced, but user is not allowed " +
                  "to change password"
      flash[:error] = l(:notice_can_t_change_password)
      redirect_to :action => 'login'
      return true
    end
    false
  end

  def render_password_change(message)
    flash[:error] = message
    @username = params[:username]
    render 'my/password'
  end

  # Register a user depending on Setting.self_registration
  def register_user_according_to_setting(user, &block)
    case Setting.self_registration
    when '1'
      register_by_email_activation(user, &block)
    when '3'
      register_automatically(user, &block)
    else
      register_manually_by_administrator(user, &block)
    end
  end

  # Register a user for email activation.
  #
  # Pass a block for behavior when a user fails to save
  def register_by_email_activation(user, &block)
    token = Token.new(:user => user, :action => "register")
    if user.save and token.save
      UserMailer.user_signed_up(token).deliver
      flash[:notice] = l(:notice_account_register_done)
      redirect_to :action => 'login'
    else
      yield if block_given?
    end
  end

  # Automatically register a user
  #
  # Pass a block for behavior when a user fails to save
  def register_automatically(user, &block)
    # Automatic activation
    user.activate
    user.last_login_on = Time.now

    if user.save
      self.logged_user = user
      flash[:notice] = l(:notice_account_registered_and_logged_in)
      redirect_after_login(user)
    else
      yield if block_given?
    end
  end

  # Manual activation by the administrator
  #
  # Pass a block for behavior when a user fails to save
  def register_manually_by_administrator(user, &block)
    if user.save
      # Sends an email to the administrators
      admins = User.admin.active
      admins.each do |admin|
        UserMailer.account_activation_requested(admin, user).deliver
      end
      account_pending
    else
      yield if block_given?
    end
  end

  def account_pending
    flash[:notice] = l(:notice_account_pending)
    # Set back_url to make sure user is not redirected to an external login page
    # when registering via the external service. This also redirects the user
    # to the original page where the user clicked on the omniauth login link for a provider.
    redirect_to :action => 'login', :back_url => params[:back_url]
  end

  def redirect_after_login(user)
    if user.first_login
      user.update_attribute(:first_login, false)
      redirect_to :controller => "/my", :action => "first_login", :back_url => params[:back_url]
    else
      redirect_back_or_default :controller => '/my', :action => 'page'
    end
  end
end
