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

describe Activity::WorkPackageActivityProvider do
  let(:event_scope)               { 'work_packages' }
  let(:work_package_edit_event)   { 'work_package-edit' }
  let(:work_package_closed_event) { 'work_package-closed' }

  let(:user)          { FactoryGirl.create :admin }
  let(:role)          { FactoryGirl.create :role }
  let(:status_closed) { FactoryGirl.create :closed_status }
  let(:work_package)  { FactoryGirl.build  :work_package }
  let!(:workflow)     { FactoryGirl.create :workflow,
                                           old_status: work_package.status,
                                           new_status: status_closed,
                                           type_id: work_package.type_id,
                                           role: role }

  describe '#event_type' do
    describe 'latest event' do
      let(:subject) { Activity::WorkPackageActivityProvider.find_events(event_scope, user, Date.today, Date.tomorrow, {}).last.try :event_type }

      context 'when a work package has been created' do
        before { work_package.save! }

        it { should == work_package_edit_event }

        context 'and has been closed' do
          before do
            allow(User).to receive(:current).and_return(user)

            work_package.status = status_closed
            work_package.save!
          end

          it { should == work_package_closed_event }
        end
      end
    end
  end
end
