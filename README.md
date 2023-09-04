# bs
A project generation tool for library package modules and dependencies.

### Functions
* `bs_project(<major_version> <minor_version>)`
* `bs_generate_package(<pkg_name> [<dependency_target>...])`
* `bs_truncate_path(<root_path> <full_path>)`
* `bs_copy_data(<relative_path>)`
* `bs_set_pedantic_flags(<pkg_name>)`

### Typical usage:
```
cmake_minimum_required (VERSION 3.0.2)
list(APPEND CMAKE_MODULE_PATH <CMAKE_CURRENT_LIST_DIR>/cmake)
include(bs)
bs_project(<project name>)
```

### Packages
Call `bs_generate_package()` in the `CMakeLists.txt` file within the current package folder with the name of the package.
Provide any necessary dependencies (targets) that the package depend upon.
The generator does not care if the target is internally or externally defined, any available targets can be utilized as dependencies.
Package interdependency is not managed and should be designed hierarchially by the user to avoid circular dependencies.

Your packages are expected to have a specific layout. See below.
All folders in a package are scanned recursively.

### Package folder layout of a package 'packagename'
  package_name
  * include
  * source
  * tests
  * CMakeLists.txt

  include
  * package_name (use the package name to add include path structure)
  ** further structure etc

  source
  * common (required for all portable translation units)
  * other platform name

  tests
  * common (source folder for tests)
  * data (test data folder accessed in tests with \"./tests/data\")

Platform specific packages are named as the following 
 `<package name><CONFIG_PLATFORM>`
and depend on the platform agnostic package <package name> by default

### Example package CMakeLists.txt file
```
cmake_minimum_required (VERSION 3.0.2)
project(<package name>)
set(deps [<library targets>...])
bs_generate_package(tools \"\${deps}\")
```
