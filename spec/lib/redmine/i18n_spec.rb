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

module OpenProject
  describe I18n do
    include Redmine::I18n

    let(:format) { '%d/%m/%Y' }

    after do
      Time.zone = nil
    end

    describe 'with user time zone' do
      before { allow(User.current).to receive(:time_zone).and_return(ActiveSupport::TimeZone['Athens'])}
      it 'returns a date in the user timezone for a utc timestamp' do
        Time.zone = 'UTC'
        time = Time.zone.local(2013, 06, 30, 23, 59)
        expect(format_time_as_date(time,format)).to eq '01/07/2013'
      end

      it 'returns a date in the user timezone for a non-utc timestamp' do
        Time.zone = 'Berlin'
        time = Time.zone.local(2013, 06, 30, 23, 59)
        expect(format_time_as_date(time,format)).to eq '01/07/2013'
      end
    end

    describe 'without user time zone' do
      before { allow(User.current).to receive(:time_zone).and_return(nil)}

      it 'returns a date in the local system timezone for a utc timestamp' do
        Time.zone = 'UTC'
        time = Time.zone.local(2013, 06, 30, 23, 59)
        allow(time).to receive(:localtime).and_return(ActiveSupport::TimeZone['Athens'].local(2013, 07, 01, 01, 59))
        expect(format_time_as_date(time,format)).to eq '01/07/2013'
      end

      it 'returns a date in the original timezone for a non-utc timestamp' do
        Time.zone = 'Berlin'
        time = Time.zone.local(2013, 06, 30, 23, 59)
        expect(format_time_as_date(time,format)).to eq '30/06/2013'
      end
    end
  end
end
