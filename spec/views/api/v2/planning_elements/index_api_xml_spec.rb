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

require File.expand_path('../../../../../spec_helper', __FILE__)

describe 'api/v2/planning_elements/index.api.rabl' do
  before do
    params[:format] = 'xml'
  end

  describe 'with no planning elements available' do
    before do
      assign(:planning_elements, [])
      render
    end
    subject {response.body}

    it 'renders an empty planning_elements document' do
      should have_selector('planning_elements', :count => 1)
      should have_selector('planning_elements[type=array]') do
        without_tag 'planning_element'
      end
    end
  end

  describe 'with 3 planning elements available' do
    let(:project){FactoryGirl.build(:project_with_types, name: "Sample Project", identifier: "sample_project")}
    let(:wp1){FactoryGirl.build(:work_package, subject: "Subject #1", project: project)}
    let(:wp2){FactoryGirl.build(:work_package, subject: "Subject #2", project: project)}
    let(:wp3){FactoryGirl.build(:work_package, subject: "Subject #3", project: project)}

    let(:planning_elements) {[wp1, wp2, wp3]}

    before do
      assign(:planning_elements, planning_elements)
      render
    end

    subject {Nokogiri.XML(response.body)}

    it 'renders a planning_elements document with the size 3 of array' do
      should have_selector('planning_elements', :count => 1)
      should have_selector('planning_elements planning_element', :count => 3)
    end

    it 'renders the subject' do
      first_planning_element = subject.xpath('//planning_elements/planning_element')[0]
      expect(first_planning_element).to have_selector("subject", text: "Subject #1")
    end



  end
end
