# bs
A project generation tool for library package modules and dependencies

### Functions
* bs_project(<major version> <minor version>)
* bs_generate_package(<package name> [<dependency targets>...])
* bs_message(<message>)

### Internal functions
* bs_internal_set_pedantic_flags(<package name>)
* bs_internal_copy_test_data(<package name>)

### Typical usage:
```
cmake_minimum_required (VERSION 3.0.2)
list(APPEND CMAKE_MODULE_PATH <CMAKE_CURRENT_LIST_DIR>/cmake)
include(bs)
bs_project(<project name>)
```

### Packages
Call bs_generate_package(<package name>) in the CMakeLists.txt file within the current package folder with the name of the package.
Provide any necessary targets that the package depend upon.
Package interdependency is not managed and should be designed hierarchially by the user.

Your package is expected to have a specific layout. Folders are scanned recursively.

### Package folder layout of a package 'packagename'
  packagename
  * include
  * source
  * tests
  * CMakeLists.txt

  include
  * packagename (use the package name to add include path structure)
  ** <further structure etc>

  source
  * common (required for all portable translation units)
  * windows (optional platform folder <CMAKE_SYSTEM_NAME> in lowercase
  * darwin
  * linux
  * android

  tests
  * common (source folder for tests)
  * data (test data folder accessed in tests with \"./tests/data\")

Platform specific packages are named as the following 
 `<package name><CONFIG_PLATFORM>`
and depend on the platform agnostic package <package name> by default

### Example package CMakeLists.txt file
```
cmake_minimum_required (VERSION 3.0.2)
project(<packagename>)
set(deps [<library targets>...])
bs_generate_package(tools \"\${deps}\")
```
