//-- copyright
// OpenProject is a project management system.
// Copyright (C) 2012-2014 the OpenProject Foundation (OPF)
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See doc/COPYRIGHT.rdoc for more details.
//++

angular.module('openproject.workPackages.directives')

.directive('workPackagesTable', ['I18n', function(I18n){
  return {
    restrict: 'E',
    replace: true,
    templateUrl: '/templates/work_packages/work_packages_table.html',
    scope: {
      projectIdentifier: '=',
      numberOfDisplayedRows: '=',
      columns: '=',
      rows: '=',
      query: '=',
      countByGroup: '=',
      groupBy: '=',
      groupByColumn: '=',
      displaySums: '=',
      totalSums: '=',
      groupSums: '=',
      updateResults: '&',
      withLoading: '=',
      updateBackUrl: '='
    },
    link: function(scope, element, attributes) {
      scope.I18n = I18n;
      scope.locale = I18n.locale;

      // groupings
      scope.grouped = scope.groupByColumn !== undefined;
      scope.groupExpanded = {};

      scope.setCheckedStateForAllRows = function(state) {
        angular.forEach(scope.rows, function(row) {
          row.checked = state;
        });
      };

      scope.$watch('query.sortation.sortElements', function(oldValue, newValue) {
        if (newValue !== oldValue) {
          scope.updateResults();
          scope.updateBackUrl();
        }
      });
    }
  };
}]);
