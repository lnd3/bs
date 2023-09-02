cmake_minimum_required (VERSION 3.0.2)

function(bs_message msg)
	message(${msg})
endfunction()

function(bs_project major_version minor_version)
	include(CTest)
	enable_testing()
	set_property(GLOBAL PROPERTY USE_FOLDERS ON)
	set(CMAKE_CXX_STANDARD 20 PARENT_SCOPE)
	set(CXX_STANDARD_REQUIRED ON PARENT_SCOPE)
	set(VERSION_MAJOR ${major_version} PARENT_SCOPE)
	set(VERSION_MINOR ${minor_version} PARENT_SCOPE)
	set(TEST_ROOT ${PROJECT_SOURCE_DIR} PARENT_SCOPE)

	# The platform folder must be identical to CONFIG_PLATFORM for platform source to be found
	# This also affects the platform target name similarly
	string(TOLOWER ${CMAKE_SYSTEM_NAME} platform_name)
	set(CONFIG_PLATFORM ${platform_name} PARENT_SCOPE)
	
	bs_message("
###########################################################################
# Build System - alpha version 0.1.
#
# A project generation tool for library package modules and dependencies
#
##### Functions
# bs_project(<major version> <minor version>)
# bs_generate_package(<package name> [<dependency targets>...])
# bs_message(<message>)
#
##### Internal functions
# bs_internal_set_pedantic_flags(<package name>)
# bs_internal_copy_test_data(<package name>)
#
##### Typical usage:
# cmake_minimum_required (VERSION 3.0.2)
# list(APPEND CMAKE_MODULE_PATH <CMAKE_CURRENT_LIST_DIR>/cmake)
# include(bs)
# bs_project(<project name>)
#
##### Packages
# Call bs_generate_package(<package name>) in the CMakeLists.txt file
# within the current package folder with the name of the package.
# Provide any necessary targets that the package depend upon.
# Package interdependency is not managed and should be designed
# hierarchially by the user.
#
# Your package is expected to have a specific layout. Folders
# are scanned recursively.
#
##### Package folder layout of a package 'packagename'
#   packagename
#   * include
#   * source
#   * tests
#   * CMakeLists.txt
#
#   include
#   * packagename (use the package name to add include path structure)
#   ** <further structure etc>
#
#   source
#   * common (required for all portable translation units)
#   * windows (optional platform folder <CMAKE_SYSTEM_NAME> in lowercase
#   * darwin
#   * linux
#   * android
#
#   tests
#   * common (source folder for tests)
#   * data (test data folder accessed in tests with \"./tests/data\")
#
# Platform specific packages are named as the following
# <package name><CONFIG_PLATFORM> and depend on the platform agnostic
# package <package name> by default
#
##### Example package CMakeLists.txt file
#
# cmake_minimum_required (VERSION 3.0.2)
# project(<packagename>)
# set(deps [<library targets>...])
# bs_generate_package(tools \"\${deps}\")
#
###########################################################################
# Generating project '${PROJECT_NAME}'
###########################################################################

	")
endfunction()


function(bs_internal_set_pedantic_flags pkg_name)
	#target_compile_definitions(${LIBRARY_NAME_PLATFORM} PUBLIC cxx_std_17)
	if(MSVC)
		target_compile_options(${pkg_name} PRIVATE /W4 /WX /EHsc)
	else()
		target_compile_options(${pkg_name} PRIVATE -Wall -Wextra -Wpedantic -Werror)
	endif()
endfunction()

function(bs_internal_copy_test_data pkg_name)
	file(GLOB_RECURSE test_data_files 
		${CMAKE_CURRENT_SOURCE_DIR}/tests/data/*.*)

	message("Test data for '${pkg_name}'")
	foreach(test_data_file ${test_data_files})
		file(RELATIVE_PATH rel_path ${CMAKE_CURRENT_SOURCE_DIR} ${test_data_file})
		#message("file: ${test_data_file}")
		#message("tail: ${rel_path}")
		if(EXISTS ${test_data_file})
			#message("dst: ${CMAKE_CURRENT_BINARY_DIR}/${rel_path}")
			configure_file(
				${test_data_file} 
				${CMAKE_CURRENT_BINARY_DIR}/${rel_path}
				COPYONLY)
		endif()
	endforeach()
endfunction()

function(bs_generate_package pkg_name deps)

	set(CXX_STANDARD_REQUIRED ON)

	message("****")
	message("Generate package '${pkg_name}' with deps '${deps}'")
	message(" Current source dir: ${CMAKE_CURRENT_SOURCE_DIR}")
	message(" Project source dir: ${PROJECT_SOURCE_DIR}")
	message(" Source dir: ${CMAKE_SOURCE_DIR}")
	foreach(dep ${deps})
		if(TARGET ${dep})
			get_target_property(dep_include ${dep} INTERFACE_INCLUDE_DIRECTORIES)
			message(" ${pkg_name} depends on ${dep} with includes: ")
			message(" ${dep_include}")
			list(APPEND include_deps ${dep_include})
		else()
			message("¤¤¤¤ WARNING ${pkg_name} was missing target ${dep}")
			list(REMOVE_ITEM deps ${dep})
		endif()
	endforeach()

	#### library setup ####
	set(LIBRARY_NAME "${pkg_name}")

	#### common library source ####
	file(GLOB_RECURSE include_common ${CMAKE_CURRENT_SOURCE_DIR}/include/*.h)
	SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/include PREFIX include FILES ${include_common})
	file(GLOB_RECURSE code_common ${CMAKE_CURRENT_SOURCE_DIR}/source/common/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/source/common/*.h)
	SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/source/common PREFIX src FILES ${code_common})
	file(GLOB_RECURSE test_common ${CMAKE_CURRENT_SOURCE_DIR}/tests/common/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/tests/common/*.h)
	SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/tests/common PREFIX src FILES ${test_common})

	message(" Includes for library: " ${LIBRARY_NAME})
	foreach(include_file ${include_common})
		message(${include_file})
	endforeach()

	# common library setup
	if(code_common OR include_common OR include_deps)
		add_library(${LIBRARY_NAME} STATIC ${code_common} ${include_common})
		target_include_directories(${LIBRARY_NAME} 
			PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include
			${include_deps}
		)
		set_target_properties(${LIBRARY_NAME} PROPERTIES FOLDER "Packages")

		bs_internal_set_pedantic_flags(${LIBRARY_NAME})

		# library common tests
		if(test_common)
			set(TEST_LIBRARY_NAME "${LIBRARY_NAME}_test")
			add_executable(${TEST_LIBRARY_NAME} ${test_common})
			target_link_libraries(${TEST_LIBRARY_NAME} PUBLIC ${deps} ${LIBRARY_NAME})
			add_test(NAME ${TEST_LIBRARY_NAME} COMMAND ${TEST_LIBRARY_NAME})
			set_target_properties(${TEST_LIBRARY_NAME} PROPERTIES FOLDER "Packages")
			bs_internal_copy_test_data(${TEST_LIBRARY_NAME})
		endif()
	endif()

	#### platform specific library configuration ####

	if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/source/${CONFIG_PLATFORM})
		# library source and headers
		file(GLOB_RECURSE include_platform ${CMAKE_CURRENT_SOURCE_DIR}/source/${CONFIG_PLATFORM}/*.h)
		SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/source/${CONFIG_PLATFORM} PREFIX src FILES ${include_platform})
		file(GLOB_RECURSE code_platform ${CMAKE_CURRENT_SOURCE_DIR}/source/${CONFIG_PLATFORM}/*.cpp)
		SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/source/${CONFIG_PLATFORM} PREFIX src FILES ${code_platform})
		file(GLOB_RECURSE test_platform ${CMAKE_CURRENT_SOURCE_DIR}/tests/${CONFIG_PLATFORM}/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/tests/${CONFIG_PLATFORM}/*.h)
		SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/tests/${CONFIG_PLATFORM} PREFIX src FILES ${test_platform})
	
		set(LIBRARY_NAME_PLATFORM "${pkg_name}${CONFIG_PLATFORM}")
		message(" Includes for library: " ${LIBRARY_NAME_PLATFORM})
		foreach(include_file ${include_platform})
			message(${include_file})
		endforeach()

		# platform library setup
		if(code_platform OR include_deps)
			add_library(${LIBRARY_NAME_PLATFORM} STATIC ${code_platform} ${include_platform})
			target_include_directories(${LIBRARY_NAME_PLATFORM} 
				PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/source/${CONFIG_PLATFORM}
				PRIVATE ${include_deps}
			)
			target_link_libraries(${LIBRARY_NAME_PLATFORM} PRIVATE ${LIBRARY_NAME})
			set_target_properties(${LIBRARY_NAME_PLATFORM} PROPERTIES FOLDER "Packages")

			bs_internal_set_pedantic_flags(${LIBRARY_NAME_PLATFORM})

			# library tests	
			if(test_common)
				set(TEST_LIBRARY_NAME_PLATFORM "${LIBRARY_NAME_PLATFORM}_test")
				add_executable(${TEST_LIBRARY_NAME_PLATFORM} ${test_platform})
				target_link_libraries(${TEST_LIBRARY_NAME_PLATFORM} PUBLIC ${deps} ${LIBRARY_NAME} ${LIBRARY_NAME_PLATFORM})
				add_test(NAME ${TEST_LIBRARY_NAME_PLATFORM} COMMAND ${TEST_LIBRARY_NAME_PLATFORM})
				set_target_properties(${TEST_LIBRARY_NAME_PLATFORM} PROPERTIES FOLDER "Packages")
				bs_internal_copy_test_data(${TEST_LIBRARY_NAME})
			endif()
		endif()
	endif()
endfunction()
