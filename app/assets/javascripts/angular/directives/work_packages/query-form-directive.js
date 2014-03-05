angular.module('openproject.workPackages.directives')

.directive('queryForm', ['WorkPackagesTableHelper', 'WorkPackageService', function(WorkPackagesTableHelper, WorkPackageService) {

  return {
    restrict: 'EA',

    compile: function(tElement) {
      return {
        pre: function(scope) {
          scope.showQueryOptions = false;

          scope.$watch('groupBy', function(oldValue, newValue) {
            if (newValue !== oldValue) {
              scope.updateResults();
            }
          });
        }
      };
    }
  };
}]);