const xcode = require('xcode');
const fs = require('fs');
const path = require('path');
const log = require('npmlog');

const addToHeaderSearchPaths = require('./addToHeaderSearchPaths');
const getHeadersInFolder = require('./getHeadersInFolder');
const getHeaderSearchPath = require('./getHeaderSearchPath');
const getProducts = require('./getProducts');
const getTargets = require('./getTargets');
const createGroupWithMessage = require('./createGroupWithMessage');
const addFileToProject = require('./addFileToProject');
const addProjectToLibraries = require('./addProjectToLibraries');
const addSharedLibraries = require('./addSharedLibraries');
const isEmpty = require('lodash').isEmpty;
const getGroup = require('./getGroup');

/**
 * Register native module IOS adds given dependency to project by adding
 * its xcodeproj to project libraries as well as attaching static library
 * to the first target (the main one)
 *
 * If library is already linked, this action is a no-op.
 */
module.exports = function registerNativeModuleIOS(dependencyConfig, projectConfig) {
  const project = xcode.project(projectConfig.pbxprojPath).parseSync();
  const dependencyProject = xcode.project(dependencyConfig.pbxprojPath).parseSync();

  const libraries = createGroupWithMessage(project, projectConfig.libraryFolder);
  const file = addFileToProject(
    project,
    path.relative(projectConfig.sourceDir, dependencyConfig.projectPath)
  );

  const targets = getTargets(project);
  const iOStargets = targets.filter(({ isTVOS }) => !isTVOS);
  const tvOStargets = targets.filter(({ isTVOS }) => isTVOS);

  addProjectToLibraries(libraries, file);

  getTargets(dependencyProject).forEach(product =>
    (product.isTVOS ? tvOStargets : iOStargets).forEach(({ uuid }) =>
      project.addStaticLibrary(product.name, {
        target: uuid
      })
    )
  );

  addSharedLibraries(project, dependencyConfig.sharedLibraries);

  const headers = getHeadersInFolder(dependencyConfig.folder);
  if (!isEmpty(headers)) {
    addToHeaderSearchPaths(
      project,
      getHeaderSearchPath(projectConfig.sourceDir, headers)
    );
  }

  fs.writeFileSync(
    projectConfig.pbxprojPath,
    project.writeSync()
  );
};
