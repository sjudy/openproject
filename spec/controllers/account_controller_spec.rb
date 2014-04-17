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

require 'spec_helper'

describe AccountController do
  render_views

  after do
    User.delete_all
    User.current = nil
  end

  context 'POST #login' do
    let(:admin) { FactoryGirl.create(:admin) }

    describe 'User logging in with back_url' do

      it 'should redirect to a relative path' do
        post :login , :username => admin.login, :password => 'adminADMIN!', :back_url => '/'
        expect(response).to redirect_to root_path
      end

      it 'should redirect to an absolute path given the same host' do
        # note: test.host is the hostname during tests
        post :login , username: admin.login,
                      password: 'adminADMIN!',
                      back_url: 'http://test.host/work_packages/show/1'
        expect(response).to redirect_to '/work_packages/show/1'
      end

      it 'should not redirect to another host' do
        post :login , username: admin.login,
                      password: 'adminADMIN!',
                      back_url: 'http://test.foo/work_packages/show/1'
        expect(response).to redirect_to my_page_path
      end

      it 'should not redirect to another host with a protocol relative url' do
        post :login , username: admin.login,
                      password: 'adminADMIN!',
                      back_url: '//test.foo/fake'
        expect(response).to redirect_to my_page_path
      end

      it 'should create users on the fly' do
        Setting.self_registration = '0'
        allow(AuthSource).to receive(:authenticate).and_return(login: 'foo',
                                                               firstname: 'Foo',
                                                               lastname: 'Smith',
                                                               mail: 'foo@bar.com',
                                                               auth_source_id: 66)
        post :login , username: 'foo', password: 'bar'

        expect(response).to redirect_to my_first_login_path
        user = User.find_by_login('foo')
        expect(user).to be_an_instance_of User
        expect(user.auth_source_id).to eq(66)
        expect(user.current_password).to be_nil
      end

      context 'with a relative url root' do
        before do
          @old_relative_url_root = ApplicationController.relative_url_root
          ApplicationController.relative_url_root = '/openproject'
        end

        after do
          ApplicationController.relative_url_root = @old_relative_url_root
        end

        it 'should redirect to the same subdirectory with an absolute path' do
          post :login , username: admin.login,
                        password: 'adminADMIN!',
                        back_url: 'http://test.host/openproject/work_packages/show/1'
          expect(response).to redirect_to '/openproject/work_packages/show/1'
        end

        it 'should redirect to the same subdirectory with a relative path' do
          post :login , username: admin.login,
                        password: 'adminADMIN!',
                        back_url: '/openproject/work_packages/show/1'
          expect(response).to redirect_to '/openproject/work_packages/show/1'
        end

        it 'should not redirect to another subdirectory with an absolute path' do
          post :login , username: admin.login,
                        password: 'adminADMIN!',
                        back_url: 'http://test.host/foo/work_packages/show/1'
          expect(response).to redirect_to my_page_path
        end

        it 'should not redirect to another subdirectory with a relative path' do
          post :login , username: admin.login,
                        password: 'adminADMIN!',
                        back_url: '/foo/work_packages/show/1'
          expect(response).to redirect_to my_page_path
        end

        it 'should not redirect to another subdirectory by going up the path hierarchy' do
          post :login , username: admin.login,
                        password: 'adminADMIN!',
                        back_url: 'http://test.host/openproject/../foo/work_packages/show/1'
          expect(response).to redirect_to my_page_path
        end

        it 'should not redirect to another subdirectory with a protocol relative path' do
          post :login , username: admin.login,
                        password: 'adminADMIN!',
                        back_url: '//test.host/foo/work_packages/show/1'
          expect(response).to redirect_to my_page_path
        end
      end

    end
  end


  describe 'Login for user with forced password change' do
    let(:admin) { FactoryGirl.create(:admin, :force_password_change => true) }

    before do
      allow_any_instance_of(User).to receive(:change_password_allowed?).and_return(false)
    end

    describe "User who is not allowed to change password can't login" do
      before do
        post 'change_password', :username => admin.login,
                                :password => 'adminADMIN!',
                                :new_password => 'adminADMIN!New',
                                :new_password_confirmation => 'adminADMIN!New'
      end

      it 'should redirect to the login page' do
        expect(response).to redirect_to '/login'
      end
    end

    describe 'User who is not allowed to change password, is not redirected to the login page' do
      before do
        post 'login', :username => admin.login, :password => 'adminADMIN!'
      end

      it 'should redirect ot the login page' do
        expect(response).to redirect_to '/login'
      end
    end
  end

  context 'GET #register' do
    context 'with self registration on' do
      before do
        allow(Setting).to receive(:self_registration).and_return('3')
        get :register
      end

      it 'is successful' do
        should respond_with :success
        expect(response).to render_template :register
        expect(assigns[:user]).not_to be_nil
      end
    end

    context 'with self registration off' do
      before do
        allow(Setting).to receive(:self_registration).and_return('0')
        allow(Setting).to receive(:self_registration?).and_return(false)
        get :register
      end

      it 'redirects to home' do
        should redirect_to('/') { home_url }
      end
    end
  end

  # See integration/account_test.rb for the full test
  context 'POST #register' do
    context 'with self registration on automatic' do
      before do
        allow(Setting).to receive(:self_registration).and_return('3')
        post :register, :user => {
          :login => 'register',
          :password => 'adminADMIN!',
          :password_confirmation => 'adminADMIN!',
          :firstname => 'John',
          :lastname => 'Doe',
          :mail => 'register@example.com'
        }
      end

      it 'redirects to first_login page' do
        should respond_with :redirect
        expect(assigns[:user]).not_to be_nil
        should redirect_to(my_first_login_path)
        expect(User.last(:conditions => { :login => 'register' })).not_to be_nil
      end

      it 'set the user status to active' do
        user = User.last(:conditions => { :login => 'register' })
        expect(user).not_to be_nil
        expect(user.status).to eq(User::STATUSES[:active])
      end
    end

    context 'with self registration by email' do
      before do
        allow(Setting).to receive(:self_registration).and_return('1')
        Token.delete_all
        post :register, :user => {
          :login => 'register',
          :password => 'adminADMIN!',
          :password_confirmation => 'adminADMIN!',
          :firstname => 'John',
          :lastname => 'Doe',
          :mail => 'register@example.com'
        }
      end

      it 'redirects to the login page' do
        should redirect_to '/login'
      end

      it "doesn't activate the user but sends out a token instead" do
        expect(User.find_by_login('register')).not_to be_active
        token = Token.find(:first)
        expect(token.action).to eq('register')
        expect(token.user.mail).to eq('register@example.com')
        expect(token).not_to be_expired
      end
    end

    context 'with manual activation' do
      let(:user_hash) do
        { :login => 'register',
          :password => 'adminADMIN!',
          :password_confirmation => 'adminADMIN!',
          :firstname => 'John',
          :lastname => 'Doe',
          :mail => 'register@example.com' }
      end

      before do
        allow(Setting).to receive(:self_registration).and_return('2')
      end

      context 'without back_url' do
        before do
          post :register, :user => user_hash
        end

        it 'redirects to the login page' do
          expect(response).to redirect_to '/login'
        end

        it "doesn't activate the user" do
          expect(User.find_by_login('register')).not_to be_active
        end
      end

      context 'with back_url' do
        before do
          post :register, :user => user_hash, :back_url => 'https://example.net/some_back_url'
        end

        it 'preserves the back url' do
          expect(response).to redirect_to(
            '/login?back_url=https%3A%2F%2Fexample.net%2Fsome_back_url')
        end
      end
    end

    context 'with self registration off' do
      before do
        allow(Setting).to receive(:self_registration).and_return('0')
        allow(Setting).to receive(:self_registration?).and_return(false)
        post :register, :user => {
          :login => 'register',
          :password => 'adminADMIN!',
          :password_confirmation => 'adminADMIN!',
          :firstname => 'John',
          :lastname => 'Doe',
          :mail => 'register@example.com'
        }
      end

      it 'redirects to home' do
        should redirect_to('/') { home_url }
      end
    end

    context 'with on-the-fly registration' do

      before do
        allow(Setting).to receive(:self_registration).and_return('0')
        allow(Setting).to receive(:self_registration?).and_return(false)
        allow_any_instance_of(User).to receive(:change_password_allowed?).and_return(false)
        allow(AuthSource).to receive(:authenticate).and_return(login: 'foo',
                                                               lastname: 'Smith',
                                                               auth_source_id: 66)

        post :login, :username => 'foo', :password => 'bar'
      end

      it 'registers the user on-the-fly' do
        should respond_with :success
        expect(response).to render_template :register

        post :register, :user => { firstname: 'Foo',
                                   lastname: 'Smith',
                                   mail: 'foo@bar.com' }
        expect(response).to redirect_to '/my/account'

        user = User.find_by_login('foo')

        expect(user).to be_an_instance_of(User)
        expect(user.auth_source_id).to eql 66
        expect(user.current_password).to be_nil
      end
    end
  end


end
