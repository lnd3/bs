# bs
A project generation tool for library package modules and dependencies.

The main purpose of `bs` is to provide a simpler interface (compared to raw cmake) to construct hierarchial project dependencies with as little cmake interaction as possible.

### Main functions
* `bs_init()`
* `bs_configure_packages(<package_rel_dir> [<used_package>...])`
* `bs_generate_package(<pkg_name> [<dependency_target>...])`

### Support functions
* `bs_truncate_path(<root_path> <full_path>)`
* `bs_set_pedantic_flags(<pkg_name>)`
* `bs_copy_to_binary_dir(<relative_path>)`

### Typical usage:
```
cmake_minimum_required (VERSION 3.0.2)
list(APPEND CMAKE_MODULE_PATH <CMAKE_CURRENT_LIST_DIR>/cmake)
include(bs)
bs_init()
set(PACKAGE_NAMES
	logging
	testing
)
# packages in folder "packages"
bs_configure_packages("packages" "${PACKAGE_NAMES}")
```

### Packages
Call `bs_generate_package()` in the `CMakeLists.txt` file within the current package folder with the name of the package.
Provide any necessary dependencies (targets) that the package depend upon.
The generator does not care if the target is internally or externally defined, any available targets can be utilized as dependencies.
Package interdependency is not managed and should be designed hierarchially by the user to avoid circular dependencies.

Your packages are expected to have a specific layout. See below.
All folders in a package are scanned recursively.

### Package folder layout of a package 'pkg_name'
  `<pkg_name>`
  * include
  * source
  * tests
  * CMakeLists.txt

  include
  * `<pkg_name>` (use a folder named <pkg_name> to add structure to the include path)
  * `<pkg_name>/<further structure etc>`

  source
  * common (required for all portable translation units)
  * `<other platform names>`

  tests
  * common (source folder for tests)
  * data (test data folder accessed in tests with "./tests/data)

Platform specific packages are named as the following 
 `<package name><CONFIG_PLATFORM>`
and depend on the platform agnostic package `<pkg_name>` by default

### Example package CMakeLists.txt file
```
cmake_minimum_required (VERSION 3.0.2)
project(<pkg_name>)
set(deps [<library targets>...])
bs_generate_package(tools "${deps}")
```
