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

describe Message, "authorization" do
  let(:created_message) { FactoryGirl.create(:message, :author => user) }
  let(:board) { created_message.board }
  let(:project) { board.project }
  let(:user) { FactoryGirl.create(:user) }
  let(:role) { FactoryGirl.build(:role, :permissions => [ ]) }
  let(:member) { FactoryGirl.build(:member, :project => project,
                                            :roles => [role],
                                            :principal => user) }
  describe :visible do
    before { created_message }

    it "should be visible if user has the view_messages permission in the project" do
      role.permissions = [:view_messages]
      member.save!

      expect(Message.visible(user)).to match_array([created_message])
    end

    it "should not be visible if user lacks the view_messages permission in the project" do
      expect(Message.visible(user)).to match_array([])
    end
  end

  describe :visible? do
    before { created_message }

    it "should be true if user has the view_messages permission in the project" do
      role.permissions = [:view_messages]
      member.save!
      # TODO: check why this is needed
      user.reload

      expect(created_message.visible?(user)).to be_true
    end

    it "should be false if user lacks the view_messages permission in the project" do
      expect(created_message.visible?(user)).to be_false
    end

  end
end
