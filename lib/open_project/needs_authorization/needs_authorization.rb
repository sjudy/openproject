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

module OpenProject::NeedsAuthorization
  module NeedsAuthorization
    def self.included(base)
      base.extend(InitMethods)
    end

    module InitMethods
      def needs_authorization(options)
        self.class_eval do
          class_attribute :authorization_options

          self.authorization_options = options

          self.include(InstanceMethods)
          self.extend(ClassMethods)
        end
      end
    end

    module ClassMethods
      def visible(*args)
        user = args.first || User.current

        project_authorization_scope.merge(Project.allowed(user, authorization_options[:view]))
      end

      protected

      def project_authorization_scope
        # TODO: might want to place that in initialization
        # to not have to evaluate this on every call
        case self.authorization_project_association
        when Symbol, Hash
          self.includes(self.authorization_project_association)
        when Class
          self.authorization_project_association.scoped
        else
          raise "Unknown project association"
        end
      end

      def authorization_project_association
        authorization_options[:project_association] || :project
      end
    end

    module InstanceMethods
      def editable?(usr)
        edit_permission = self.class.authorization_options[:edit]
        edit_own_permission = self.class.authorization_options[:edit_own]

        usr.allowed_to?(edit_permission, project) ||
        usr.allowed_to?(edit_own_permission, project) && self.user_id == usr.id
      end

      def visible?(usr)
        # TODO: project has to changed so that other associations are possible
        usr.allowed_to?(self.class.authorization_options[:view], authorization_project)
      end

      protected

      def authorization_project
        case self.authorization_project_association
        when Symbol
          self.send(self.authorization_project_association)
        when Hash
          # this assumes the hash to be single path only, e.g.:
          # symbol => { symbol => symbol }
          navigate_to_project(self.authorization_project_association)
          #self.authorization_project_association.inject(self) { |object,
        when Class
          # TODO: this is a hack for project for which it works
          self#.authorization_project_association
        else
          raise "Unknown project association"
        end
      end

      def authorization_project_association
        authorization_options[:project_association] || :project
      end

      def navigate_to_project(path)
        navigate_to_project_on(self, path)
      end

      def navigate_to_project_on(project_memo, path)
        case path
        when Hash
          array = path.to_a.flatten

          project_memo = project_memo.send(array.first)

          navigate_to_project_on(project_memo, array.last)
        when Symbol
          project_memo.send(path)
        end

      end
    end
  end
end
