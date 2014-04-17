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

describe UsersController do
  before do
    User.delete_all
  end

  after do
    User.current = nil
  end

  let(:user) { FactoryGirl.create(:user) }
  let(:admin) { FactoryGirl.create(:admin) }
  let(:anonymous) { FactoryGirl.create(:anonymous) }

  describe "GET deletion_info" do

    describe "WHEN the current user is the requested user
              WHEN the setting users_deletable_by_self is set to true" do
      let(:params) { { "id" => user.id.to_s } }

      before do
        allow(Setting).to receive(:users_deletable_by_self?).and_return(true)

        as_logged_in_user user do
          get :deletion_info, params
        end
      end

      it { expect(response).to be_success }
      it { expect(assigns(:user)).to eq(user) }
      it { expect(response).to render_template("deletion_info") }
    end

    describe "WHEN the current user is the requested user
              WHEN the setting users_deletable_by_self is set to false" do
      let(:params) { { "id" => user.id.to_s } }

      before do
        allow(Setting).to receive(:users_deletable_by_self?).and_return(false)

        as_logged_in_user user do
          get :deletion_info, params
        end
      end

      it { expect(response.response_code).to eq(404) }
    end

    describe "WHEN the current user is the anonymous user" do
      let(:params) { { "id" => anonymous.id.to_s } }

      before do
        as_logged_in_user anonymous do
          get :deletion_info, params
        end
      end

      it { expect(response).to redirect_to({ :controller => 'account',
                                         :action => 'login',
                                         :back_url => @controller.url_for({ :controller => 'users',
                                                                            :action => 'deletion_info' }) }) }
    end

    describe "WHEN the current user is admin
              WHEN the setting users_deletable_by_admins is set to true" do
      let(:params) { { "id" => user.id.to_s } }

      before do
        allow(Setting).to receive(:users_deletable_by_admins?).and_return(true)

        as_logged_in_user admin do
          get :deletion_info, params
        end
      end

      it { expect(response).to be_success }
      it { expect(assigns(:user)).to eq(user) }
      it { expect(response).to render_template("deletion_info") }
    end

    describe "WHEN the current user is admin
              WHEN the setting users_deletable_by_admins is set to false" do
      let(:params) { { "id" => user.id.to_s } }

      before do
        allow(Setting).to receive(:users_deletable_by_admins?).and_return(false)

        as_logged_in_user admin do
          get :deletion_info, params
        end
      end

      it { expect(response.response_code).to eq(404) }
    end
  end

  describe "POST destroy" do
    describe "WHEN the current user is the requested one
              WHEN the setting users_deletable_by_self is set to true" do
      let(:params) { { "id" => user.id.to_s } }

      before do
        disable_flash_sweep
        allow(Setting).to receive(:users_deletable_by_self?).and_return(true)

        as_logged_in_user user do
          post :destroy, params
        end
      end

      it { expect(response).to redirect_to({ :controller => 'account', :action => 'login' }) }
      it { expect(flash[:notice]).to eq(I18n.t('account.deleted')) }
    end

    describe "WHEN the current user is the requested one
              WHEN the setting users_deletable_by_self is set to false" do
      let(:params) { { "id" => user.id.to_s } }

      before do
        disable_flash_sweep
        allow(Setting).to receive(:users_deletable_by_self?).and_return(false)

        as_logged_in_user user do
          post :destroy, params
        end
      end

      it { expect(response.response_code).to eq(404) }
    end

    describe "WHEN the current user is the anonymous user
              EVEN when the setting login_required is set to false" do
      let(:params) { { "id" => anonymous.id.to_s } }

      before do
        allow(@controller).to receive(:find_current_user).and_return(anonymous)
        allow(Setting).to receive(:login_required?).and_return(false)

        as_logged_in_user anonymous do
          post :destroy, params
        end
      end

      # redirecting post is not possible for now
      it { expect(response.response_code).to eq(403) }
    end

    describe "WHEN the current user is the admin
              WHEN the setting users_deletable_by_admins is set to true" do
      let(:admin) { FactoryGirl.create(:admin) }
      let(:params) { { "id" => user.id.to_s } }

      before do
        disable_flash_sweep
        allow(Setting).to receive(:users_deletable_by_admins?).and_return(true)

        as_logged_in_user admin do
          post :destroy, params
        end
      end

      it { expect(response).to redirect_to({ :controller => 'users', :action => 'index' }) }
      it { expect(flash[:notice]).to eq(I18n.t('account.deleted')) }
    end

    describe "WHEN the current user is the admin
              WHEN the setting users_deletable_by_admins is set to false" do
      let(:admin) { FactoryGirl.create(:admin) }
      let(:params) { { "id" => user.id.to_s } }

      before do
        disable_flash_sweep
        allow(Setting).to receive(:users_deletable_by_admins).and_return(false)

        as_logged_in_user admin do
          post :destroy, params
        end
      end

      it { expect(response.response_code).to eq(404) }
    end
  end

  describe :change_status do
    describe 'WHEN activating a registered user' do
      let!(:registered_user) do
        FactoryGirl.create(:user, :status => User::STATUSES[:registered],
                                  :language => 'de')
      end

      before do
        ActionMailer::Base.deliveries.clear
        with_settings(:available_languages => [:en, :de],
                      :bcc_recipients => '1') do
          as_logged_in_user admin do
            post :change_status, :id => registered_user.id,
                                 :user => {:status => User::STATUSES[:active]},
                                 :activate => '1'
          end
        end
      end

      it 'should activate the user' do
        assert registered_user.reload.active?
      end

      it 'should send an email to the correct user in the correct language' do
        mail = ActionMailer::Base.deliveries.last
        assert_not_nil mail
        assert_equal [registered_user.mail], mail.to
        mail.parts.each do |part|
          assert part.body.encoded.include?(I18n.t(:notice_account_activated,
                                                   :locale => 'de'))
        end
      end
    end
  end

  describe "index" do
    describe "with session lifetime" do
      # TODO move this section to a proper place because we test a
      # before_filter from the application controller

      after(:each) do
        # reset, so following tests are not affected by the change
        User.current = nil
      end

      shared_examples_for "index action with disabled session lifetime or inactivity not exceeded" do
        it "doesn't logout the user and renders the index action" do
          expect(User.current).to eq(admin)
          expect(response).to render_template "index"
        end
      end

      shared_examples_for 'index action with enabled session lifetime and inactivity exceeded' do
        it "logs out the user and redirects with a warning that he has been locked out" do
          expect(response.redirect_url).to eq(signin_url + "?back_url=" + CGI::escape(@controller.url_for(:controller => "users", :action => "index")))
          expect(User.current).not_to eq(admin)
          expect(flash[:warning]).to eq(I18n.t(:notice_forced_logout, :ttl_time => Setting.session_ttl))
        end
      end

      context "disabled" do
        before do
          allow(Setting).to receive(:session_ttl_enabled?).and_return(false)
          @controller.send(:logged_user=, admin)
          get :index
        end

        it_should_behave_like 'index action with disabled session lifetime or inactivity not exceeded'
      end

      context "enabled " do
        before do
          allow(Setting).to receive(:session_ttl_enabled?).and_return(true)
          allow(Setting).to receive(:session_ttl).and_return("120")
          @controller.send(:logged_user=, admin)
        end

        context "before 120 min of inactivity" do
          before do
            session[:updated_at] = Time.now - 1.hours
            get :index
          end

          it_should_behave_like 'index action with disabled session lifetime or inactivity not exceeded'
        end

        context "after 120 min of inactivity" do
          before do
            session[:updated_at] = Time.now - 3.hours
            get :index
          end
          it_should_behave_like 'index action with enabled session lifetime and inactivity exceeded'
        end

        context "without last activity time in the session" do
          before do
            allow(Setting).to receive(:session_ttl).and_return("60")
            session[:updated_at] = nil
            get :index
          end
          it_should_behave_like 'index action with enabled session lifetime and inactivity exceeded'
        end

        context "with ttl = 0" do
          before do
            allow(Setting).to receive(:session_ttl).and_return("0")
            session[:updated_at] = Time.now - 1.hours
            get :index
          end

          it_should_behave_like 'index action with disabled session lifetime or inactivity not exceeded'
        end

        context "with ttl < 0" do
          before do
            allow(Setting).to receive(:session_ttl).and_return("-60")
            session[:updated_at] = Time.now - 1.hours
            get :index
          end

          it_should_behave_like 'index action with disabled session lifetime or inactivity not exceeded'
        end

        context "with ttl < 5 > 0" do
          before do
            allow(Setting).to receive(:session_ttl).and_return("4")
            session[:updated_at] = Time.now - 1.hours
            get :index
          end

          it_should_behave_like 'index action with disabled session lifetime or inactivity not exceeded'
        end
      end
    end
  end

  describe "update" do
    context "fields" do
      let(:user) { FactoryGirl.create(:user, :firstname => 'Firstname',
                                             :admin => true,
                                             :login => 'testlogin',
                                             :mail_notification => 'all',
                                             :force_password_change => false)}

      before do
        ActionMailer::Base.deliveries.clear

        as_logged_in_user(admin) do
          put :update, :id => user.id, :user => {:admin => false,
                                                 :firstname => 'Changed',
                                                 :login => 'changedlogin',
                                                 :mail_notification => 'only_assigned',
                                                 :force_password_change => true},
                                       :pref => {:hide_mail => '1', :comments_sorting => 'desc'}
       end
      end

      it 'should redirect to the edit page' do
        expect(response).to redirect_to(edit_user_url(user))
      end

      it 'should be assigned their new values' do
        user_from_db = User.find(user.id)
        expect(user_from_db.admin).to be_false
        expect(user_from_db.firstname).to eql('Changed')
        expect(user_from_db.login).to eql('changedlogin')
        expect(user_from_db.mail_notification).to eql('only_assigned')
        expect(user_from_db.force_password_change).to eql(true)
        expect(user_from_db.pref[:hide_mail]).to be_true
        expect(user_from_db.pref[:comments_sorting]).to eql('desc')
      end

      it 'should not send an email' do
        expect(ActionMailer::Base.deliveries.empty?).to be_true
      end
    end

    context "with external authentication" do
      let(:user) { FactoryGirl.create(:user, :identity_url => 'some:identity')}

      before do
        as_logged_in_user(admin) do
          put :update, :id => user.id, :user => {:force_password_change => 'true'}
        end
        user.reload
      end

      it 'should ignore setting force_password_change' do
        expect(user.force_password_change).to eql(false)
      end
    end

    context "ldap auth source" do
      let(:ldap_auth_source) { FactoryGirl.create(:ldap_auth_source) }

      it "switchting to internal authentication on a password change" do
        user.auth_source = ldap_auth_source
        as_logged_in_user admin do
          put :update, :id => user.id, :user => {:auth_source_id => '', :password => 'newpassPASS!', :password_confirmation => 'newpassPASS!'}
        end

        expect(user.reload.auth_source).to be_nil
        expect(user.check_password?('newpassPASS!')).to be_true
      end
    end
  end

  describe "update memberships" do
    let(:project) { FactoryGirl.create(:project) }
    let(:role) { FactoryGirl.create(:role) }

    it "works" do
      # i.e. it should successfully add a user to a project's members
      as_logged_in_user admin do
        post :edit_membership,
          :id => user.id,
          :membership => {
            :project_id => project.id,
            :role_ids => [role.id]
          },
          :format => "js"
      end

      expect(response.status).to eql(200)

      is_member = user.reload.memberships.any? do |m|
        m.project_id == project.id && m.role_ids.include?(role.id)
      end
      expect(is_member).to eql(true)
    end
  end

  describe "Anonymous should not be able to create a user" do

    it "should redirect to the login page" do
      post :create, :user => { :login => 'psmith', :firstname => 'Paul', :lastname => 'Smith'}, :password => "psmithPSMITH09", :password_confirmation => "psmithPSMITH09"
      expect(response).to redirect_to '/login?back_url=http%3A%2F%2Ftest.host%2Fusers'
    end

  end

  describe "show" do
    describe "general" do
      before do
        as_logged_in_user user do
          get :show, :id => user.id
        end
      end

      it "responds with success" do
        expect(response).to be_success
      end

      it "renders the show template" do
        expect(response).to render_template 'show'
      end

      it "assigns @user" do
        expect(assigns(:user)).to eq(user)
      end
    end

    describe 'for user with Activity' do
      render_views

      let(:work_package) { FactoryGirl.create(:work_package,
                                              author: user) }
      let!(:member) { FactoryGirl.create(:member,
                                         project: work_package.project,
                                         principal: user,
                                         roles: [FactoryGirl.create(:role,
                                                                    permissions: [:view_work_packages])]) }
      let!(:journal_1) { FactoryGirl.create(:work_package_journal,
                                            user: user,
                                            journable_id: work_package.id,
                                            version: Journal.maximum(:version) + 1,
                                            data: FactoryGirl.build(:journal_work_package_journal,
                                                                    subject: work_package.subject,
                                                                    status_id: work_package.status_id,
                                                                    type_id: work_package.type_id,
                                                                    project_id: work_package.project_id)) }
      let!(:journal_2) { FactoryGirl.create(:work_package_journal,
                                            user: user,
                                            journable_id: work_package.id,
                                            version: Journal.maximum(:version) + 1,
                                            data: FactoryGirl.build(:journal_work_package_journal,
                                                                    subject: work_package.subject,
                                                                    status_id: work_package.status_id,
                                                                    type_id: work_package.type_id,
                                                                    project_id: work_package.project_id)) }

      before { allow(User).to receive(:current).and_return(user.reload) }

      it { get :show, id: user.id }
    end
  end
end
