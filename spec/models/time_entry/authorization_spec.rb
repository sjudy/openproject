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

describe TimeEntry, "authorization" do
  let(:created_time_entry) { FactoryGirl.create(:time_entry,
                                                :project => project,
                                                :user => user,
                                                :work_package => work_package) }
  let(:project) { FactoryGirl.create(:project_with_types) }
  let(:user) { FactoryGirl.create(:user) }
  let(:role) { FactoryGirl.build(:role, :permissions => [ ]) }
  let(:member) { FactoryGirl.build(:member, :project => project,
                                            :roles => [role],
                                            :principal => user) }
  let(:work_package) { FactoryGirl.build(:work_package, :type => project.types.first,
                                         :author => user,
                                         :project => project,
                                         :status => status) }
  let(:status) { FactoryGirl.create(:status) }

  describe :visible do
    it "should be visible if user has the view_time_entry permission in the project" do
      role.permissions = [:view_time_entries]
      member.save!

      expect(TimeEntry.visible(user)).to match_array([created_time_entry])
    end

    it "should not be visible if user lacks the view_time_entry permission in the project" do
      created_time_entry

      expect(TimeEntry.visible(user)).to match_array([])
    end
  end

  describe :editable? do
    it "should be editable if user has the edit_time_entries permission in the project" do
      role.permissions = [:edit_time_entries]
      member.save!

      expect(created_time_entry.editable?(user)).to be_true
    end

    it "should not be editable if user lacks the edit_time_entries permission in the project" do
      created_time_entry

      expect(created_time_entry.editable?(user)).to be_false
    end

    it "should be editable if user has the edit_own_time_entries permission in the project and the time entry belongs to the user" do
      role.permissions = [:edit_own_time_entries]
      member.save!

      expect(created_time_entry.editable?(user)).to be_true
    end

    it "should not be editable if user has the edit_own_time_entries permission in the project and the time entry belongs to a different user" do
      role.permissions = [:edit_own_time_entries]
      member.save!

      created_time_entry.user = FactoryGirl.create(:user)
      created_time_entry.save!

      expect(created_time_entry.editable?(user)).to be_false
    end
  end
end
