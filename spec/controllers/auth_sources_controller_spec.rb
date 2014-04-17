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

require File.expand_path('../../spec_helper', __FILE__)

describe AuthSourcesController do
  let(:current_user) { FactoryGirl.create(:admin) }

  before do
    allow(User).to receive(:current).and_return current_user
  end

  describe "index" do
    before do
      get :index
    end

    it { expect(assigns(:auth_source)).to eq @auth_source }
    it { should respond_with :success }
    it { should render_template :index }
  end

  describe "new" do
    before do
      get :new
    end

    it { expect(assigns(:auth_source)).not_to be_nil }
    it { should respond_with :success }
    it { should render_template :new }

    it "initializes a new AuthSource" do
      expect(assigns(:auth_source).class).to eq(AuthSource)
      expect(assigns(:auth_source)).to be_new_record
    end
  end

  describe "create" do
    before do
      post :create, :auth_source => {:name => 'Test'}
    end

    it { should respond_with :redirect }
    it { should redirect_to auth_sources_path }
    it { should set_the_flash.to /success/i }
  end

  describe "edit" do
    before do
      @auth_source = AuthSource.generate!(:name => 'TestEdit')
      get :edit, id: @auth_source.id
    end

    it { expect(assigns(:auth_source)).to eq @auth_source }
    it { should respond_with :success }
    it { should render_template :edit }
  end

  describe "update" do
    before do
      @auth_source = AuthSource.generate!(:name => 'TestEdit')
      post :update, id: @auth_source.id, auth_source: {name: 'TestUpdate'}
    end

    it { should respond_with :redirect }
    it { should redirect_to auth_sources_path }
    it { should set_the_flash.to /update/i }
  end

  describe "destroy" do
    before do
      @auth_source = AuthSource.generate!(:name => 'TestEdit')
    end

    context "without users" do
      before do
        post :destroy, id: @auth_source.id
      end

      it { should respond_with :redirect }
      it { should redirect_to auth_sources_path }
      it { should set_the_flash.to /deletion/i }
    end

    context "with users" do
      before do
        User.generate!(:auth_source => @auth_source)
        post :destroy, id: @auth_source.id
      end

      it { should respond_with :redirect }
      it "doesn not destroy the AuthSource" do
        expect(AuthSource.find(@auth_source.id)).not_to be_nil
      end
    end
  end
end
