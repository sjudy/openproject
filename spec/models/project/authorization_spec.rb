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

describe Project, "authorization" do
  let(:created_project) { FactoryGirl.create(:project) }
  let(:user) { FactoryGirl.create(:user) }
  let(:role) { FactoryGirl.build(:role, :permissions => [ ]) }
  let(:member) { FactoryGirl.build(:member, :project => created_project,
                                            :roles => [role],
                                            :principal => user) }
  describe :visible do
    it "should be visible if user is member of the project (regardless of the permission)" do
      member.save!

      expect(Project.visible(user)).to match_array([created_project])
    end

    it "should not be visible if the user is no member in the project" do
      created_project

      expect(Project.visible(user)).to match_array([])
    end
  end

  describe :visible? do
    it "should be true if user is member of the project (regardless of the permission)" do
      member.save!

      expect(created_project.visible?(user)).to be_true
    end

    it "should be false if the user is no member in the project" do
      expect(created_project.visible?(user)).to be_false
    end
  end
end
