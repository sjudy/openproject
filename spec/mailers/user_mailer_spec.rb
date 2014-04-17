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

require 'spec_helper'

describe UserMailer do
  let(:type_standard) { FactoryGirl.build_stubbed(:type_standard) }
  let(:user) { FactoryGirl.build_stubbed(:user) }
  let(:journal) { FactoryGirl.build_stubbed(:work_package_journal) }
  let(:work_package) { FactoryGirl.build_stubbed(:work_package,
                                                 type: type_standard) }

  before do
    allow(work_package).to receive(:reload).and_return(work_package)

    allow(journal).to receive(:journable).and_return(work_package)
    allow(journal).to receive(:user).and_return(user)

    allow(Setting).to receive(:mail_from).and_return('john@doe.com')
    allow(Setting).to receive(:host_name).and_return('mydomain.foo')
    allow(Setting).to receive(:protocol).and_return('http')
    allow(Setting).to receive(:default_language).and_return('en')
  end

  describe :test_mail do
    let(:test_email) { 'bob.bobbi@example.com' }
    let(:test_user) { User.new(firstname: 'Bob', lastname: 'Bobbi', mail: test_email) }
    let(:mail) { UserMailer.test_mail(test_user) }

    before do
      # the name method uses a format setting to determine how to concatenate first name
      # and last name whereby an unescaped comma will lead to have two email addresses
      # defined instead of one (['Bobbi', 'bob.bobbi@example.com'] vs. ['bob.bobbi@example.com'])
      test_user.stub(:name).and_return('Bobbi, Bob')
    end

     it 'escapes the name attribute properly' do
       expect(mail.to).to eql [test_email]
     end
  end

  describe :issue_update do
    context :delayed_job do
      before do
        # Delayed Job does not preserve the closure, so the context of the
        # delayed method call does not contain the user anymore, who triggered
        # the job. Instead, the anonymous user is returned.
        User.current = User.anonymous

        UserMailer.work_package_updated(user, journal, user)
      end

      it { expect(User.current).to eq(user) }

      after do
        User.current = User.anonymous
      end
    end
  end

  describe :wiki_content_updated do
    let(:wiki_content) { FactoryGirl.create(:wiki_content) }
    let!(:mail) { UserMailer.wiki_content_updated(user, wiki_content) }

    it "should link to the latest version diff page" do
      expect(mail.body.encoded).to include "diff/2"
    end

    after do
      User.current = nil
    end
  end

  describe :message_id do
    describe 'same user' do
      let(:journal_2) { FactoryGirl.build_stubbed(:work_package_journal) }

      before do
        allow(journal_2).to receive(:journable).and_return(work_package)
        allow(journal_2).to receive(:user).and_return(user)
        allow(journal_2).to receive(:created_at).and_return(journal.created_at + 5.seconds)
      end

      subject do
        message_ids = [journal, journal_2].each_with_object([]) do |j, l|
          l << UserMailer.work_package_updated(user, j).message_id
        end

        message_ids.uniq.count
      end

      it { expect(subject).to eq(2) }
    end

    describe 'same timestamp' do
      let(:user_2) { FactoryGirl.build_stubbed(:user) }

      before do
        allow(work_package).to receive(:recipients).and_return([user, user_2])
      end

      subject do
        message_ids = [user, user_2].each_with_object([]) do |u, l|
          l << UserMailer.work_package_updated(u, journal).message_id
        end

        message_ids.uniq.count
      end

      it { expect(subject).to eq(2) }
    end
  end

  describe 'journal details' do
    subject { UserMailer.work_package_updated(user, journal).body.encoded }

    describe 'plain text mail' do
      before do
        allow(Setting).to receive(:plain_text_mail).and_return('1')
      end

      describe 'done ration modifications' do
        context 'changed done ratio' do
          before do
            allow(journal).to receive(:details).and_return({"done_ratio" => [40, 100]})
          end

          it 'displays changed done ratio' do
            should match("% done changed from 40 to 100")
          end
        end

        context 'new done ratio' do
          before do
            allow(journal).to receive(:details).and_return({"done_ratio" => [nil, 100]})
          end

          it 'displays new done ratio' do
            should match("% done changed from 0 to 100")
          end
        end

        context 'deleted done ratio' do
          before do
            allow(journal).to receive(:details).and_return({"done_ratio" => [50, nil]})
          end

          it 'displays deleted done ratio' do
            should match("% done changed from 50 to 0")
          end
        end
      end

      describe 'start_date attribute' do
        context 'format the start date' do
          before do
            allow(journal).to receive(:details).and_return({"start_date" => ['2010-01-01', '2010-01-31']})
          end

          it 'old date should be formatted' do
            should match("01/01/2010")
          end

          it 'new date should be formatted' do
            should match("01/31/2010")
          end
        end
      end

      describe 'due_date attribute' do
        context 'format the end date' do
          before do
            allow(journal).to receive(:details).and_return({"due_date" => ['2010-01-01', '2010-01-31']})
          end

          it 'old date should be formatted' do
            should match("01/01/2010")
          end

          it 'new date should be formatted' do
            should match("01/31/2010")
          end
        end
      end

      describe 'project attribute' do
        let(:project_1) { FactoryGirl.create(:project) }
        let(:project_2) { FactoryGirl.create(:project) }

        before do
          allow(journal).to receive(:details).and_return({"project_id" => [project_1.id, project_2.id]})
        end

        it "shows the old project's name" do
          should match(project_1.name)
        end

        it "shows the new project's name" do
          should match(project_2.name)
        end
      end

      describe 'attribute issue status' do
        let(:status_1) { FactoryGirl.create(:status) }
        let(:status_2) { FactoryGirl.create(:status) }

        before do
          allow(journal).to receive(:details).and_return({"status_id" => [status_1.id, status_2.id]})
        end

        it "shows the old status' name" do
          should match(status_1.name)
        end

        it "shows the new status' name" do
          should match(status_2.name)
        end
      end

      describe 'attribute type' do
        let(:type_1) { FactoryGirl.create(:type_standard) }
        let(:type_2) { FactoryGirl.create(:type_bug) }

        before do
          allow(journal).to receive(:details).and_return({"type_id" => [type_1.id, type_2.id]})
        end

        it "shows the old type's name" do
          should match(type_1.name)
        end

        it "shows the new type's name" do
          should match(type_2.name)
        end
      end

      describe 'attribute assigned to' do
        let(:assignee_1) { FactoryGirl.create(:user) }
        let(:assignee_2) { FactoryGirl.create(:user) }

        before do
          allow(journal).to receive(:details).and_return({"assigned_to_id" => [assignee_1.id, assignee_2.id]})
        end

        it "shows the old assignee's name" do
          should match(assignee_1.name)
        end

        it "shows the new assignee's name" do
          should match(assignee_2.name)
        end
      end

      describe 'attribute priority' do
        let(:priority_1) { FactoryGirl.create(:priority) }
        let(:priority_2) { FactoryGirl.create(:priority) }

        before do
          allow(journal).to receive(:details).and_return({"priority_id" => [priority_1.id, priority_2.id]})
        end

        it "shows the old priority's name" do
          should match(priority_1.name)
        end

        it "shows the new priority's name" do
          should match(priority_2.name)
        end
      end

      describe 'attribute category' do
        let(:category_1) { FactoryGirl.create(:category) }
        let(:category_2) { FactoryGirl.create(:category) }

        before do
          allow(journal).to receive(:details).and_return({"category_id" => [category_1.id, category_2.id]})
        end

        it "shows the old category's name" do
          should match(category_1.name)
        end

        it "shows the new category's name" do
          should match(category_2.name)
        end
      end

      describe 'attribute fixed version' do
        let(:version_1) { FactoryGirl.create(:version) }
        let(:version_2) { FactoryGirl.create(:version) }

        before do
          allow(journal).to receive(:details).and_return({"fixed_version_id" => [version_1.id, version_2.id]})
        end

        it "shows the old version's name" do
          should match(version_1.name)
        end

        it "shows the new version's name" do
          should match(version_2.name)
        end
      end

      describe 'attribute estimated hours' do
        let(:estimated_hours_1) { 30.5678 }
        let(:estimated_hours_2) { 35.912834 }

        before do
          allow(journal).to receive(:details).and_return({"estimated_hours" => [estimated_hours_1, estimated_hours_2]})
        end

        it "shows the old estimated hours" do
          should match('%.2f' % estimated_hours_1)
        end

        it "shows the new estimated hours" do
          should match('%.2f' % estimated_hours_2)
        end
      end

      describe 'custom field' do
        let(:expected_text_1) { "original, unchanged text" }
        let(:expected_text_2) { "modified, new text" }
        let(:custom_field) { FactoryGirl.create :work_package_custom_field,
                                                field_format: "text" }

        before do
          allow(journal).to receive(:details).and_return({"custom_fields_#{custom_field.id}" => [expected_text_1, expected_text_2]})
        end

        it "shows the old custom field value" do
          should match(expected_text_1)
        end

        it "shows the new custom field value" do
          should match(expected_text_2)
        end
      end

      describe 'attachments' do
        let(:attachment) { FactoryGirl.create :attachment }

        context 'added' do
          before do
            allow(journal).to receive(:details).and_return({"attachments_#{attachment.id}" => [nil, attachment.filename]})
          end

          it "shows the attachment's filename" do
            should match(attachment.filename)
          end

          it "shows status 'added'" do
            should match('added')
          end

          it "shows no status 'deleted'" do
            should_not match('deleted')
          end
        end

        context 'removed' do
          before do
            allow(journal).to receive(:details).and_return({"attachments_#{attachment.id}" => [attachment.filename, nil]})
          end

          it "shows the attachment's filename" do
            should match(attachment.filename)
          end

          it "shows no status 'added'" do
            should_not match('added')
          end

          it "shows status 'deleted'" do
            should match('deleted')
          end
        end
      end
    end

    describe 'html mail' do
      let(:expected_translation) { I18n.t(:done_ratio, :scope => [:activerecord,
                                                                  :attributes,
                                                                  :work_package]) }
      let(:expected_prefix) { "<li><strong>#{expected_translation}</strong>" }

      before do
        allow(Setting).to receive(:plain_text_mail).and_return('0')
      end

      context 'changed done ratio' do
        let(:expected) { "#{expected_prefix} changed from <i>40</i> to <i>100</i>" }

        before do
          allow(journal).to receive(:details).and_return({"done_ratio" => [40, 100]})
        end

        it 'displays changed done ratio' do
          should match(expected)
        end
      end

      context 'new done ratio' do
        let(:expected) { "#{expected_prefix} changed from <i>0</i> to <i>100</i>" }

        before do
          allow(journal).to receive(:details).and_return({"done_ratio" => [nil, 100]})
        end

        it 'displays new done ratio' do
          should match(expected)
        end
      end

      context 'deleted done ratio' do
        let(:expected) { "#{expected_prefix} changed from <i>50</i> to <i>0</i>" }

        before do
          allow(journal).to receive(:details).and_return({"done_ratio" => [50, nil]})
        end

        it 'displays deleted done ratio' do
          should match(expected)
        end
      end
    end
  end
end
