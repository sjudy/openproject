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

describe WorkPackage do
  let(:stub_work_package) { FactoryGirl.build_stubbed(:work_package) }
  let(:stub_version) { FactoryGirl.build_stubbed(:version) }
  let(:stub_project) { FactoryGirl.build_stubbed(:project) }
  let(:work_package) { FactoryGirl.create(:work_package) }
  let(:user) { FactoryGirl.create(:user) }

  let(:type) { FactoryGirl.create(:type_standard) }
  let(:project) { FactoryGirl.create(:project, types: [type]) }
  let(:status) { FactoryGirl.create(:status) }
  let(:priority) { FactoryGirl.create(:priority) }
  let(:work_package) { WorkPackage.new.tap do |w|
                         w.force_attributes = { project_id: project.id,
                           type_id: type.id,
                           author_id: user.id,
                           status_id: status.id,
                           priority: priority,
                           subject: 'test_create',
                           description: 'WorkPackage#create',
                           estimated_hours: '1:30' }
                       end }

  describe "create" do
    describe :save do
      subject { work_package.save }

      it { should be_true }
    end

    describe :estimated_hours do
      before do
        work_package.save!
        work_package.reload
      end

      subject { work_package.estimated_hours }

      it { should eq(1.5) }
    end

    describe "minimal" do
      let(:work_package_minimal) { WorkPackage.new.tap do |w|
                                     w.force_attributes = { project_id: project.id,
                                       type_id: type.id,
                                       author_id: user.id,
                                       status_id: status.id,
                                       priority: priority,
                                       subject: 'test_create' }
                                 end }

      context :save do
        subject { work_package_minimal.save }

        it { should be_true }
      end

      context :description do
        before do
          work_package_minimal.save!
          work_package_minimal.reload
        end

        subject { work_package_minimal.description }

        it { should be_nil }
      end
    end

    describe :assigned_to do
      context :group_assignment do
        let(:group) { FactoryGirl.create(:group) }

        before do
          allow(Setting).to receive(:work_package_group_assignment).and_return(true)
        end

        subject { FactoryGirl.create(:work_package,
                                     assigned_to: group).assigned_to }

        it { should eq(group) }
      end
    end
  end

  describe :type do
    context "disabled type" do
      describe "allows work package update" do
        before do
          work_package.save!

          project.types.delete work_package.type

          work_package.reload
          work_package.subject = "New subject"
        end

        subject { work_package.save }

        it { should be_true }
      end

      describe "must not be set on work package" do
        before do
          project.types.delete work_package.type
        end

        context :save do
          subject { work_package.save }

          it { should be_false }
        end

        context :errors do
          before { work_package.save }

          subject { work_package.errors[:type_id] }

          it { should_not be_empty }
        end
      end
    end
  end

  describe :category do
    let(:user_2) { FactoryGirl.create(:user, member_in_project: project) }
    let(:category) { FactoryGirl.create(:category,
                                        project: project,
                                        assigned_to: user_2) }

    before do
      work_package.force_attributes = { category_id: category.id }
      work_package.save!
    end

    subject { work_package.assigned_to }

    it { should eq(category.assigned_to) }
  end

  describe :assignable_assignees do
    let(:user) { FactoryGirl.build_stubbed(:user) }

    context "single user" do
      before { allow(stub_work_package.project).to receive(:possible_assignees).and_return([user]) }

      subject { stub_work_package.assignable_assignees }

      it 'should return all users the project deems to be possible assignees' do
        should include(user)
      end
    end

    context "with work_package_group_assignment" do
      let(:group) { FactoryGirl.create(:group) }
      let(:work_package) { FactoryGirl.create(:work_package) }

      before do
        allow(Setting).to receive(:work_package_group_assignment?).and_return(true)
        work_package.project.add_member! group, FactoryGirl.create(:role)
      end

      subject { work_package.assignable_assignees }
      it { should include(group) }
    end

    context "without work_package_group_assignment" do
      let(:group) { FactoryGirl.create(:group) }
      let(:work_package) { FactoryGirl.create(:work_package) }

      before do
        allow(Setting).to receive(:work_package_group_assignment?).and_return(false)
        work_package.project.add_member! group, FactoryGirl.create(:role)
      end

      subject { work_package.assignable_assignees }
      it { should_not include(group) }
    end

    context "multiple users" do
      let(:user_2) { FactoryGirl.build_stubbed(:user) }

      before { allow(stub_work_package.project).to receive(:assignable_assignees).and_return([user, user_2]) }

      subject { stub_work_package.assignable_assignees.uniq }

      it { should eq(stub_work_package.assignable_assignees) }
    end
  end

  describe :assignable_responsibles do
    let(:user) { FactoryGirl.create(:user) }
    let(:group) { FactoryGirl.create(:group) }

    before do
      work_package.project.add_member! user, FactoryGirl.create(:role)
      work_package.project.add_member! group, FactoryGirl.create(:role)
    end

    subject { work_package.assignable_responsibles }

    it { should_not include(group) }
    it { should include(user) }
  end

  describe :assignable_versions do
    def stub_shared_versions(v = nil)
      versions = v ? [v] : []

      # open seems to be defined on the array's singleton class
      # as such it seems not possible to stub it
      # achieving the same here
      versions.define_singleton_method :open do
        self
      end

      allow(stub_work_package.project).to receive(:shared_versions).and_return(versions)
    end

    it "should return all the project's shared versions" do
      stub_shared_versions(stub_version)

      expect(stub_work_package.assignable_versions).to eq([stub_version])
    end

    it "should return the current fixed_version" do
      stub_shared_versions

      allow(stub_work_package).to receive(:fixed_version_id_was).and_return(5)
      allow(Version).to receive(:find_by_id).with(5).and_return(stub_version)

      expect(stub_work_package.assignable_versions).to eq([stub_version])
    end
  end

  describe :assignable_versions do
    let(:work_package) { FactoryGirl.build(:work_package,
                                           project: project,
                                           fixed_version: version) }
    let(:version_open) { FactoryGirl.create(:version,
                                            status: 'open',
                                            project: project) }
    let(:version_locked) { FactoryGirl.create(:version,
                                              status: 'locked',
                                              project: project) }
    let(:version_closed) { FactoryGirl.create(:version,
                                              status: 'closed',
                                              project: project) }

    describe :assignment do
      context "open version" do
        let(:version) { version_open }

        subject { work_package.assignable_versions.collect(&:status).uniq }

        it { should include('open') }
      end

      shared_examples_for "invalid version" do
        before { work_package.save }

        subject { work_package.errors[:fixed_version_id] }

        it { should_not be_empty }
      end

      context "closed version" do
        let(:version) { version_closed }

        it_behaves_like "invalid version"
      end

      context "locked version" do
        let(:version) { version_locked }

        it_behaves_like "invalid version"
      end

      context "open version" do
        let(:version) { version_open }

        before { work_package.save }

        it { should be_true }
      end
    end

    describe "work package update" do
      let(:status_closed) { FactoryGirl.create(:status,
                                               is_closed: true) }
      let(:status_open) { FactoryGirl.create(:status,
                                             is_closed: false) }

      context "closed version" do
        let(:version) { FactoryGirl.create(:version,
                                           status: 'open',
                                           project: project) }

        before do
          version_open

          work_package.status = status_closed
          work_package.save!
        end

        shared_context "in closed version" do
          before do
            version.status = 'closed'
            version.save!
          end
        end

        context "attribute update" do
          include_context "in closed version"

          before { work_package.subject = "Subject changed" }

          subject { work_package.save }

          it { should be_true }
        end

        context "status changed" do
          let!(:workflow) { FactoryGirl.create(:workflow,
                                               old_status: status_closed,
                                               new_status: status_open,
                                               type_id: work_package.type_id) }
          let(:user) { FactoryGirl.create(:user) }
          let!(:membership) { FactoryGirl.create(:member,
                                                 user: user,
                                                 project: work_package.project,
                                                 roles: [workflow.role]) }

          before { allow(User).to receive(:current).and_return(user) }

          shared_context "in locked version" do
            before do
              version.status = 'locked'
              version.save!
            end
          end

          shared_examples_for "save with open version" do
            before do
              work_package.status = status_open
              work_package.fixed_version = version_open
            end

            subject { work_package.save }

            it { should be_true }
          end

          context "in closed version" do
            include_context "in closed version"

            before do
              work_package.status = status_open
              work_package.save
            end

            subject { work_package.errors[:base] }

            it { should_not be_empty }
          end

          context "from closed version" do
            include_context "in closed version"

            it_behaves_like "save with open version"
          end

          context "from locked version" do
            include_context "in locked version"

            it_behaves_like "save with open version"
          end
        end
      end
    end
  end

  describe :move do
    let(:work_package) { FactoryGirl.create(:work_package,
                                            project: project,
                                            type: type) }
    let(:target_project) { FactoryGirl.create(:project) }

    shared_examples_for "moved work package" do
      subject { work_package.project }

      it { should eq(target_project) }
    end

    describe :time_entries do
      let(:time_entry_1) { FactoryGirl.create(:time_entry,
                                              project: project,
                                              work_package: work_package) }
      let(:time_entry_2) { FactoryGirl.create(:time_entry,
                                              project: project,
                                              work_package: work_package) }

      before do
        time_entry_1
        time_entry_2

        work_package.reload
        work_package.move_to_project(target_project)

        time_entry_1.reload
        time_entry_2.reload
      end

      context "time entry 1" do
        subject { work_package.time_entries }

        it { should include(time_entry_1) }
      end

      context "time entry 2" do
        subject { work_package.time_entries }

        it { should include(time_entry_2) }
      end

      it_behaves_like "moved work package"
    end

    describe :category do
      let(:category) { FactoryGirl.create(:category,
                                          project: project) }

      before do
        work_package.category = category
        work_package.save!

        work_package.reload
      end

      context "with same category" do
        let(:target_category) { FactoryGirl.create(:category,
                                                   name: category.name,
                                                   project: target_project) }

        before do
          target_category

          work_package.move_to_project(target_project)
        end

        describe "category moved" do
          subject { work_package.category_id }

          it { should eq(target_category.id) }
        end

        it_behaves_like "moved work package"
      end

      context "w/o target category" do
        before { work_package.move_to_project(target_project) }

        describe "category discarded" do
          subject { work_package.category_id }

          it { should be_nil }
        end

        it_behaves_like "moved work package"
      end
    end

    describe :version do
      let(:sharing) { 'none' }
      let(:version) { FactoryGirl.create(:version,
                                         status: 'open',
                                         project: project,
                                         sharing: sharing) }
      let(:work_package) { FactoryGirl.create(:work_package,
                                              fixed_version: version,
                                              project: project) }

      before { work_package.move_to_project(target_project) }

      it_behaves_like "moved work package"

      context "unshared version" do
        subject { work_package.fixed_version }

        it { should be_nil }
      end

      context "system wide shared version" do
        let(:sharing) { 'system' }

        subject { work_package.fixed_version }

        it { should eq(version) }
      end

      context "move work package in project hierarchy" do
        let(:target_project) { FactoryGirl.create(:project,
                                                  parent: project) }

        context "unshared version" do
          subject { work_package.fixed_version }

          it { should be_nil }
        end

        context "shared version" do
          let(:sharing) { 'tree' }

          subject { work_package.fixed_version }

          it { should eq(version) }
        end
      end
    end

    describe :type do
      let(:target_type) { FactoryGirl.create(:type) }
      let(:target_project) { FactoryGirl.create(:project,
                                                types: [ target_type ]) }

      subject { work_package.move_to_project(target_project) }

      it { should be_false }
    end
  end

  describe :destroy do
    let(:time_entry_1) { FactoryGirl.create(:time_entry,
                                            project: project,
                                            work_package: work_package) }
    let(:time_entry_2) { FactoryGirl.create(:time_entry,
                                            project: project,
                                            work_package: work_package) }

    before do
      time_entry_1
      time_entry_2

      work_package.destroy
    end

    context "work package" do
      subject { WorkPackage.find_by_id(work_package.id) }

      it { should be_nil }
    end

    context "time entries" do
      subject { TimeEntry.find_by_work_package_id(work_package.id) }

      it { should be_nil }
    end
  end

  describe :done_ratio do
    let(:status_new) { FactoryGirl.create(:status,
                                          name: 'New',
                                          is_default: true,
                                          is_closed: false,
                                          default_done_ratio: 50) }
    let(:status_assigned) { FactoryGirl.create(:status,
                                               name: 'Assigned',
                                               is_default: true,
                                               is_closed: false,
                                               default_done_ratio: 0) }
    let(:work_package_1) { FactoryGirl.create(:work_package,
                                              status: status_new) }
    let(:work_package_2) { FactoryGirl.create(:work_package,
                                              project: work_package_1.project,
                                              status: status_assigned,
                                              done_ratio: 30) }

    before { work_package_2 }

    describe :value do
      context "work package field" do
        before { allow(Setting).to receive(:work_package_done_ratio).and_return 'field' }

        context "work package 1" do
          subject { work_package_1.done_ratio }

          it { should eq(0) }
        end

        context "work package 2" do
          subject { work_package_2.done_ratio }

          it { should eq(30) }
        end
      end

      context "work package status" do
        before { allow(Setting).to receive(:work_package_done_ratio).and_return 'status' }

        context "work package 1" do
          subject { work_package_1.done_ratio }

          it { should eq(50) }
        end

        context "work package 2" do
          subject { work_package_2.done_ratio }

          it { should eq(0) }
        end
      end
    end

    describe :update_done_ratio_from_status do
      context "work package field" do
        before do
          allow(Setting).to receive(:work_package_done_ratio).and_return 'field'

          work_package_1.update_done_ratio_from_status
          work_package_2.update_done_ratio_from_status
        end

        it "does not update the done ratio" do
          expect(work_package_1.done_ratio).to eq(0)
          expect(work_package_2.done_ratio).to eq(30)
        end
      end

      context "work package status" do
        before do
          allow(Setting).to receive(:work_package_done_ratio).and_return 'status'

          work_package_1.update_done_ratio_from_status
          work_package_2.update_done_ratio_from_status
        end

        it "updates the done ratio" do
          expect(work_package_1.done_ratio).to eq(50)
          expect(work_package_2.done_ratio).to eq(0)
        end
      end
    end
  end

  describe :group_by do
    let(:type_2) { FactoryGirl.create(:type) }
    let(:priority_2) { FactoryGirl.create(:priority) }
    let(:project) { FactoryGirl.create(:project, types: [type, type_2]) }
    let(:version_1) { FactoryGirl.create(:version,
                                         project: project) }
    let(:version_2) { FactoryGirl.create(:version,
                                         project: project) }
    let(:category_1) { FactoryGirl.create(:category,
                                          project: project) }
    let(:category_2) { FactoryGirl.create(:category,
                                          project: project) }
    let(:user_2) { FactoryGirl.create(:user) }

    let(:work_package_1) { FactoryGirl.create(:work_package,
                                              author: user,
                                              assigned_to: user,
                                              responsible: user,
                                              project: project,
                                              type: type,
                                              priority: priority,
                                              fixed_version: version_1,
                                              category: category_1) }
    let(:work_package_2) { FactoryGirl.create(:work_package,
                                              author: user_2,
                                              assigned_to: user_2,
                                              responsible: user_2,
                                              project: project,
                                              type: type_2,
                                              priority: priority_2,
                                              fixed_version: version_2,
                                              category: category_2) }

    before do
      work_package_1
      work_package_2
    end

    shared_examples_for "group by" do
      context :size do
        subject { groups.size }

        it { should eq(2) }
      end

      context :total do
        subject { groups.inject(0) {|sum, group| sum + group['total'].to_i} }

        it { should eq(2) }
      end
    end

    context "by type" do
      let(:groups) { WorkPackage.by_type(project) }

      it_behaves_like "group by"
    end

    context "by version" do
      let(:groups) { WorkPackage.by_version(project) }

      it_behaves_like "group by"
    end

    context "by priority" do
      let(:groups) { WorkPackage.by_priority(project) }

      it_behaves_like "group by"
    end

    context "by category" do
      let(:groups) { WorkPackage.by_category(project) }

      it_behaves_like "group by"
    end

    context "by assigned to" do
      let(:groups) { WorkPackage.by_assigned_to(project) }

      it_behaves_like "group by"
    end

    context "by responsible" do
      let(:groups) { WorkPackage.by_responsible(project) }

      it_behaves_like "group by"
    end

    context "by author" do
      let(:groups) { WorkPackage.by_author(project) }

      it_behaves_like "group by"
    end

    context "by project" do
      let(:project_2) { FactoryGirl.create(:project,
                                           parent: project) }
      let(:work_package_3) { FactoryGirl.create(:work_package,
                                                project: project_2) }

      before { work_package_3 }

      let(:groups) { WorkPackage.by_author(project) }

      it_behaves_like "group by"
    end
  end

  describe :recently_updated do
    let(:work_package_1) { FactoryGirl.create(:work_package) }
    let(:work_package_2) { FactoryGirl.create(:work_package) }

    before do
      work_package_1
      work_package_2

      without_timestamping do
        work_package_1.updated_at = 1.minute.ago
        work_package_1.save!
      end
    end

    context :limit do
      subject { WorkPackage.recently_updated.limit(1).first }

      it { should eq(work_package_2) }
    end
  end

  describe :on_active_project do
    let(:project_archived) { FactoryGirl.create(:project,
                                                status: Project::STATUS_ARCHIVED) }
    let(:work_package) { FactoryGirl.create(:work_package) }
    let(:work_package_in_archived_project) { FactoryGirl.create(:work_package,
                                                                project: project_archived) }

    before { work_package }

    subject { WorkPackage.on_active_project.length }

    context "one work package in active projects" do
      it { should eq(1) }

      context "and one work package in archived projects" do
        before { work_package_in_archived_project }

        it { should eq(1) }
      end
    end
  end

  describe :recipients do
    let(:project) { FactoryGirl.create(:project) }
    let(:member) { FactoryGirl.create(:user) }
    let(:author) { FactoryGirl.create(:user) }
    let(:assignee) { FactoryGirl.create(:user) }
    let(:role) { FactoryGirl.create(:role,
                                    permissions: [:view_work_packages]) }
    let(:project_member) { FactoryGirl.create(:member,
                                              user: member,
                                              project: project,
                                              roles: [role]) }
    let(:project_author) { FactoryGirl.create(:member,
                                              user: author,
                                              project: project,
                                              roles: [role]) }
    let(:project_assignee) { FactoryGirl.create(:member,
                                                user: assignee,
                                                project: project,
                                                roles: [role]) }
    let(:work_package) { FactoryGirl.create(:work_package,
                                            author: author,
                                            assigned_to: assignee,
                                            project: project) }

    shared_examples_for "includes expected users" do
      subject { work_package.recipients }

      it { should include(*expected_users) }
    end

    shared_examples_for "includes not expected users" do
      subject { work_package.recipients }

      it { should_not include(*expected_users) }
    end

    describe "includes project recipients" do
      before { project_member }

      context "pre-condition" do
        subject { project.recipients }

        it { should_not be_empty }
      end

      let(:expected_users) { project.recipients }

      it_behaves_like "includes expected users"
    end

    describe "includes work package author" do
      before { project_author }

      context "pre-condition" do
        subject { work_package.author }

        it { should_not be_nil }
      end

      let(:expected_users) { work_package.author.mail }

      it_behaves_like "includes expected users"
    end

    describe "includes work package assignee" do
      before { project_assignee }

      context "pre-condition" do
        subject { work_package.assigned_to }

        it { should_not be_nil }
      end

      let(:expected_users) { work_package.assigned_to.mail }

      it_behaves_like "includes expected users"
    end

    context "mail notification settings" do
      before do
        project_author
        project_assignee
      end

      describe :none do
        before { author.update_attribute(:mail_notification, :none) }

        let(:expected_users) { work_package.author.mail }

        it_behaves_like "includes not expected users"
      end

      describe :only_assigned do
        before { author.update_attribute(:mail_notification, :only_assigned) }

        let(:expected_users) { work_package.author.mail }

        it_behaves_like "includes not expected users"
      end

      describe :only_assigned do
        before { assignee.update_attribute(:mail_notification, :only_owner) }

        let(:expected_users) { work_package.assigned_to.mail }

        it_behaves_like "includes not expected users"
      end
    end
  end

  describe :new_statuses_allowed_to do

    let(:role) { FactoryGirl.create(:role) }
    let(:type) { FactoryGirl.create(:type) }
    let(:user) { FactoryGirl.create(:user) }
    let(:other_user) { FactoryGirl.create(:user) }
    let(:statuses) { (1..5).map{ |i| FactoryGirl.create(:status)}}
    let(:priority) { FactoryGirl.create :priority, is_default: true }
    let(:status) { statuses[0] }
    let(:project) do
      FactoryGirl.create(:project, :types => [type]).tap { |p| p.add_member(user, role).save }
    end
    let(:workflow_a) { FactoryGirl.create(:workflow, :role_id => role.id,
                                                     :type_id => type.id,
                                                     :old_status_id => statuses[0].id,
                                                     :new_status_id => statuses[1].id,
                                                     :author => false,
                                                     :assignee => false)}
    let(:workflow_b) { FactoryGirl.create(:workflow, :role_id => role.id,
                                                     :type_id => type.id,
                                                     :old_status_id => statuses[0].id,
                                                     :new_status_id => statuses[2].id,
                                                     :author => true,
                                                     :assignee => false)}
    let(:workflow_c) { FactoryGirl.create(:workflow, :role_id => role.id,
                                                     :type_id => type.id,
                                                     :old_status_id => statuses[0].id,
                                                     :new_status_id => statuses[3].id,
                                                     :author => false,
                                                     :assignee => true)}
    let(:workflow_d) { FactoryGirl.create(:workflow, :role_id => role.id,
                                                     :type_id => type.id,
                                                     :old_status_id => statuses[0].id,
                                                     :new_status_id => statuses[4].id,
                                                     :author => true,
                                                     :assignee => true)}
    let(:workflows) { [workflow_a, workflow_b, workflow_c, workflow_d] }

    it "should respect workflows w/o author and w/o assignee" do
      workflows
      expect(status.new_statuses_allowed_to([role], type, false, false)).to match_array([statuses[1]])
      expect(status.find_new_statuses_allowed_to([role], type, false, false)).to match_array([statuses[1]])
    end

    it "should respect workflows w/ author and w/o assignee" do
      workflows
      expect(status.new_statuses_allowed_to([role], type, true, false)).to match_array([statuses[1], statuses[2]])
      expect(status.find_new_statuses_allowed_to([role], type, true, false)).to match_array([statuses[1], statuses[2]])
    end

    it "should respect workflows w/o author and w/ assignee" do
      workflows
      expect(status.new_statuses_allowed_to([role], type, false, true)).to match_array([statuses[1], statuses[3]])
      expect(status.find_new_statuses_allowed_to([role], type, false, true)).to match_array([statuses[1], statuses[3]])
    end

    it "should respect workflows w/ author and w/ assignee" do
      workflows
      expect(status.new_statuses_allowed_to([role], type, true, true)).to match_array([statuses[1], statuses[2], statuses[3], statuses[4]])
      expect(status.find_new_statuses_allowed_to([role], type, true, true)).to match_array([statuses[1], statuses[2], statuses[3], statuses[4]])
    end

    it "should respect workflows w/o author and w/o assignee on work packages" do
      workflows
      work_package = WorkPackage.create(:type_id => type.id,
                                        :status => status,
                                        :priority => priority,
                                        :project => project)
      expect(work_package.new_statuses_allowed_to(user)).to match_array([statuses[0], statuses[1]])
    end

    it "should respect workflows w/ author and w/o assignee on work packages" do
      workflows
      work_package = WorkPackage.create(:type_id => type.id,
                                        :status => status,
                                        :priority => priority,
                                        :project => project,
                                        :author => user)
      expect(work_package.new_statuses_allowed_to(user)).to match_array([statuses[0], statuses[1], statuses[2]])
    end

    it "should respect workflows w/o author and w/ assignee on work packages" do
      workflows
      work_package = WorkPackage.create(:type_id => type.id,
                                        :status => status,
                                        :subject => "test",
                                        :priority => priority,
                                        :project => project,
                                        :assigned_to => user,
                                        :author => other_user)
      expect(work_package.new_statuses_allowed_to(user)).to match_array([statuses[0], statuses[1], statuses[3]])
    end

    it "should respect workflows w/ author and w/ assignee on work packages" do
      workflows
      work_package = WorkPackage.create(:type_id => type.id,
                                        :status => status,
                                        :subject => "test",
                                        :priority => priority,
                                        :project => project,
                                        :author => user,
                                        :assigned_to => user)
      expect(work_package.new_statuses_allowed_to(user)).to match_array([statuses[0], statuses[1], statuses[2], statuses[3], statuses[4]])
    end

  end

  describe :add_time_entry do
    it "should return a new time entry" do
      expect(stub_work_package.add_time_entry).to be_a TimeEntry
    end

    it "should already have the project assigned" do
      stub_work_package.project = stub_project

      expect(stub_work_package.add_time_entry.project).to eq(stub_project)
    end

    it "should already have the work_package assigned" do
      expect(stub_work_package.add_time_entry.work_package).to eq(stub_work_package)
    end

    it "should return an usaved entry" do
      expect(stub_work_package.add_time_entry).to be_new_record
    end
  end

  describe :update_by! do
    let(:instance) { FactoryGirl.create(:work_package) }

    it "should return true" do
      expect(instance.update_by!(user, {})).to be_true
    end

    it "should set the values" do
      instance.update_by!(user, { :subject => "New subject" })

      expect(instance.subject).to eq("New subject")
    end

    it "should create a journal with the journal's 'notes' attribute set to the supplied" do
      instance.update_by!(user, { :notes => "blubs" })

      expect(instance.journals.last.notes).to eq("blubs")
    end

    it "should attach an attachment" do
      raw_attachments = [double('attachment')]
      attachment = FactoryGirl.build(:attachment)

      expect(instance).to receive(:attach_files)
              .with(raw_attachments)
              .and_return(attachment)

      instance.update_by!(user, { :attachments => raw_attachments })
    end

    it "should only attach the attachment when saving was successful" do
      raw_attachments = [double('attachment')]

      expect(Attachment).not_to receive(:attach_files)

      instance.update_by!(user, { :subject => "", :attachments => raw_attachments })
    end

    it "should add a time entry" do
      activity = FactoryGirl.create(:time_entry_activity)

      instance.update_by!(user, { :time_entry => { "hours" => "5",
                                                  "activity_id" => activity.id.to_s,
                                                  "comments" => "blubs" } } )

      expect(instance).to have(1).time_entries

      entry = instance.time_entries.first

      expect(entry).to be_persisted
      expect(entry.work_package).to eq(instance)
      expect(entry.user).to eq(user)
      expect(entry.project).to eq(instance.project)
      expect(entry.spent_on).to eq(Date.today)
    end

    it "should not persist the time entry if the work package update fails" do
      activity = FactoryGirl.create(:time_entry_activity)

      instance.update_by!(user, { :subject => '',
                                 :time_entry => { "hours" => "5",
                                                  "activity_id" => activity.id.to_s,
                                                  "comments" => "blubs" } } )

      expect(instance).to have(1).time_entries

      entry = instance.time_entries.first

      expect(entry).not_to be_persisted
    end

    it "should not add a time entry if the time entry attributes are empty" do
      time_attributes = { "hours" => "",
                          "activity_id" => "",
                          "comments" => "" }

      instance.update_by!(user, :time_entry => time_attributes)

      expect(instance).to have(0).time_entries
    end
  end

  describe "#allowed_target_projects_on_move" do
    let(:admin_user) { FactoryGirl.create :admin }
    let(:valid_user) { FactoryGirl.create :user }
    let(:project) { FactoryGirl.create :project }

    context "admin user" do
      before do
        allow(User).to receive(:current).and_return admin_user
        project
      end

      subject { WorkPackage.allowed_target_projects_on_move.count }

      it "sees all active projects" do
        should eq Project.active.count
      end
    end

    context "non admin user" do
      before do
        allow(User).to receive(:current).and_return valid_user

        role = FactoryGirl.create :role, permissions: [:move_work_packages]

        FactoryGirl.create(:member, user: valid_user, project: project, roles: [role])
      end

      subject { WorkPackage.allowed_target_projects_on_move.count }

      it "sees all active projects" do
        should eq Project.active.count
      end
    end
  end

  describe :duration do
    #TODO remove once only WP exists
    [:work_package].each do |subclass|

      describe "for #{subclass}" do
        let(:instance) { send(subclass) }

        describe "w/ today as start date
                  w/ tomorrow as due date" do
          before do
            instance.start_date = Date.today
            instance.due_date = Date.today + 1.day
          end

          it "should have a duration of two" do
            expect(instance.duration).to eq(2)
          end
        end

        describe "w/ today as start date
                  w/ today as due date" do
          before do
            instance.start_date = Date.today
            instance.due_date = Date.today
          end

          it "should have a duration of one" do
            expect(instance.duration).to eq(1)
          end
        end

        describe "w/ today as start date
                  w/o a due date" do
          before do
            instance.start_date = Date.today
            instance.due_date = nil
          end

          it "should have a duration of one" do
            expect(instance.duration).to eq(1)
          end
        end

        describe "w/o a start date
                  w today as due date" do
          before do
            instance.start_date = nil
            instance.due_date = Date.today
          end

          it "should have a duration of one" do
            expect(instance.duration).to eq(1)
          end
        end

        describe "w/o a start date
                  w an erroneous due date" do
          before do
            instance.start_date = nil
            instance.due_date = '856742858941748214577'
          end

          it "should have a validation error" do
            expect(instance).to have(1).error_on(:due_date)
          end
        end

      end
    end
  end

  describe 'Acts as journalized' do
    before(:each) do
      Status.delete_all
      IssuePriority.delete_all

      @type ||= FactoryGirl.create(:type_feature)

      @status_resolved ||= FactoryGirl.create(:status, :name => "Resolved", :is_default => false)
      @status_open ||= FactoryGirl.create(:status, :name => "Open", :is_default => true)
      @status_rejected ||= FactoryGirl.create(:status, :name => "Rejected", :is_default => false)

      role = FactoryGirl.create(:role)
      FactoryGirl.create(:workflow,
                         old_status: @status_open,
                         new_status: @status_resolved,
                         role: role,
                         type_id: @type.id)
      FactoryGirl.create(:workflow,
                         old_status: @status_resolved,
                         new_status: @status_rejected,
                         role: role,
                         type_id: @type.id)

      @priority_low ||= FactoryGirl.create(:priority_low, :is_default => true)
      @priority_high ||= FactoryGirl.create(:priority_high)
      @project ||= FactoryGirl.create(:project_with_types)

      @current = FactoryGirl.create(:user, :login => "user1", :mail => "user1@users.com")
      allow(User).to receive(:current).and_return(@current)
      @project.add_member!(@current, role)

      @user2 = FactoryGirl.create(:user, :login => "user2", :mail => "user2@users.com")


      @issue ||= FactoryGirl.create(:work_package, :project => @project, :status => @status_open, :type => @type, :author => @current)
    end

    describe 'ignore blank to blank transitions' do
      it 'should not include the "nil to empty string"-transition' do
        @issue.description = nil
        @issue.save!

        @issue.description = ""
        expect(@issue.send(:incremental_journal_changes)).to be_empty
      end
    end

    describe 'Acts as journalized recreate initial journal' do
      it 'should not include certain attributes' do
        recreated_journal = @issue.recreate_initial_journal!

        expect(recreated_journal.changed_data.include?('rgt')).to eq(false)
        expect(recreated_journal.changed_data.include?('lft')).to eq(false)
        expect(recreated_journal.changed_data.include?('lock_version')).to eq(false)
        expect(recreated_journal.changed_data.include?('updated_at')).to eq(false)
        expect(recreated_journal.changed_data.include?('updated_on')).to eq(false)
        expect(recreated_journal.changed_data.include?('id')).to eq(false)
        expect(recreated_journal.changed_data.include?('type')).to eq(false)
        expect(recreated_journal.changed_data.include?('root_id')).to eq(false)
      end

      it 'should not include useless transitions' do
        recreated_journal = @issue.recreate_initial_journal!

        recreated_journal.changed_data.values.each do |change|
          expect(change.first).not_to eq(change.last)
        end
      end

      it 'should not be different from the initially created journal by aaj' do
        # Creating four journals total
        @issue.status = @status_resolved
        @issue.assigned_to = @user2
        @issue.save!
        @issue.reload

        @issue.priority = @priority_high
        @issue.save!
        @issue.reload

        @issue.status = @status_rejected
        @issue.priority = @priority_low
        @issue.estimated_hours = 3
        @issue.save!

        initial_journal = @issue.journals.first
        recreated_journal = @issue.recreate_initial_journal!

        expect(initial_journal).to be_identical(recreated_journal)
      end

      it "should not validate with oddly set estimated_hours" do
        @issue.estimated_hours = "this should not work"
        expect(@issue).not_to be_valid
      end

      it "should validate with sane estimated_hours" do
        @issue.estimated_hours = "13h"
        expect(@issue).to be_valid
      end
    end
  end

  describe :inherit_done_ratio_from_leaves do
    describe 'with done ratio disabled' do
      let(:project) { FactoryGirl.create(:project) }
      let(:work_package) { FactoryGirl.create(:work_package, :project => project) }
      let(:child) { FactoryGirl.create(:work_package, :parent => work_package,
                                                      :project => project)}
      let(:closed_status) { FactoryGirl.create(:closed_status) }
      let!(:workflow) { FactoryGirl.create(:workflow,
                                           old_status: child.status,
                                           new_status: closed_status,
                                           type_id: child.type_id) }
      let(:user) { FactoryGirl.create(:user,
                                      member_in_project: project,
                                      member_through_role: workflow.role) }

      before do
        allow(Setting).to receive(:work_package_done_ratio).and_return('disabled')

        allow(User).to receive(:current).and_return(user)
      end

      it 'should not update the work package done_ratio' do
        expect(work_package.done_ratio).to eq(0)

        child.status = closed_status
        child.save!

        work_package.reload
        expect(work_package.done_ratio).to eq(0)
      end
    end
  end

  describe "parent work package" do
    describe "with parent_id for a not existing work package" do
      let(:project) { FactoryGirl.create(:project) }
      let(:invalid_work_package) { FactoryGirl.build(:work_package, :project => project, :parent_id => 1) }

      it 'should raise an error' do
        expect(invalid_work_package).not_to be_valid
      end
    end
  end

  describe 'custom fields' do
    it 'should not duplicate error messages when invalid' do
      cf1 = FactoryGirl.create(:work_package_custom_field, :is_required => true)
      cf2 = FactoryGirl.create(:work_package_custom_field, :is_required => true)

      # create work_package with one required custom field
      work_package = FactoryGirl.create :work_package
      work_package.project.work_package_custom_fields << cf1
      work_package.type.custom_fields << cf1

      # set that custom field with a value, should be fine
      work_package.custom_field_values = {cf1.id => 'test'}
      work_package.save!; work_package.reload

      # is it fine?
      expect(work_package).to be_valid

      # now give the work_package another required custom field, but don't assign a value
      work_package.project.work_package_custom_fields << cf2
      work_package.type.custom_fields << cf2
      work_package.custom_field_values # #custom_field_values needs to be touched

      # that should not be valid
      expect(work_package).to_not be_valid

      # assert that there is only one error
      expect(work_package.errors.size).to eq 1
      expect(work_package.errors_on(:custom_values).size).to eq 1
    end
  end

  describe 'changed_since' do
    let!(:work_package) do
      work_package = Timecop.travel(5.hours.ago) do
        wp = FactoryGirl.create(:work_package)
        wp.save!
        wp
      end
    end

    describe 'null' do
      subject { WorkPackage.changed_since(nil) }

      it { expect(subject).to match_array([work_package]) }
    end

    describe 'now' do
      subject { WorkPackage.changed_since(DateTime.now) }

      it { expect(subject).to be_empty }
    end

    describe 'work package update' do
      subject { WorkPackage.changed_since(work_package.updated_at) }

      it { expect(subject).to match_array([work_package]) }
    end
  end
end

