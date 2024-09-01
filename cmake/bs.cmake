cmake_minimum_required (VERSION 3.21.7)

# bs support functions
function(bs_truncate_path root_path full_path)
	cmake_path(RELATIVE_PATH ${full_path} BASE_DIRECTORY ${root_path} OUTPUT_VARIABLE rel_path)
	set(${full_path} ${rel_path} PARENT_SCOPE)
endfunction()

function(bs_set_pedantic_flags pkg_name)
	#target_compile_definitions(${LIBRARY_NAME_PLATFORM} PUBLIC cxx_std_17)
	if(MSVC)
		target_compile_options(${pkg_name} PRIVATE /W4 /WX /EHsc)
	else()
		target_compile_options(${pkg_name} PRIVATE -Wall -Wextra -Wpedantic -Werror)
	endif()
endfunction()

function(bs_copy_to_binary_dir relative_path)
	file(GLOB_RECURSE data_files 
		${CMAKE_CURRENT_SOURCE_DIR}/${relative_path}/*.*)

	foreach(data_file ${data_files})
		file(RELATIVE_PATH rel_path ${CMAKE_CURRENT_SOURCE_DIR} ${data_file})
		if(EXISTS ${data_file})
			configure_file(
				${data_file} 
				${CMAKE_CURRENT_BINARY_DIR}/${rel_path}
				COPYONLY)
		endif()
	endforeach()
endfunction()

# bs main api
function(bs_init)
	set_property(GLOBAL PROPERTY USE_FOLDERS ON)
	set(CMAKE_CXX_STANDARD 20 PARENT_SCOPE)
	set(CXX_STANDARD_REQUIRED ON PARENT_SCOPE)
	set(BS_ROOT_DIR ${PROJECT_SOURCE_DIR} PARENT_SCOPE)

	# The platform folder must be identical to CONFIG_PLATFORM for platform source to be found
	# This also affects the platform target name similarly
	string(TOLOWER ${CMAKE_SYSTEM_NAME} platform_name)
	string(TOLOWER ${CMAKE_SYSTEM_VERSION} platform_version)
	string(TOLOWER ${CMAKE_SYSTEM_PROCESSOR} platform_processor)
	set(BS_CONFIG_PLATFORM ${platform_name} PARENT_SCOPE)

	message("##########################################################################################")
	message("             Initialized BS for platform '${CMAKE_SYSTEM_NAME}' version '${CMAKE_SYSTEM_VERSION}'")
	message("##########################################################################################")
endfunction()

function(bs_configure_packages package_rel_dir used_packages)
	# add all package libraries directories

	foreach(packageName ${used_packages})
		add_subdirectory(${package_rel_dir}/${packageName})
	endforeach()

	# list all library target names
	foreach(packageName ${used_packages})
		set(libraryName ${packageName})
		if(TARGET ${libraryName})
			list(APPEND LIB_NAMES ${libraryName})
		endif()
	endforeach()

	# list all library target platform names
	foreach(packageName ${used_packages})
		set(libraryPlatformName ${packageName}${BS_CONFIG_PLATFORM})
		if(TARGET ${libraryPlatformName})
			list(APPEND LIB_PLATFORM_NAMES ${libraryPlatformName})
		endif()
	endforeach()

	message("Generated common libraries: " )
	foreach(packageName ${LIB_NAMES})
		message("   ${packageName}")
	endforeach()
	message("Generated platform libraries: " )
	foreach(packageName ${LIB_PLATFORM_NAMES})
		message("   ${packageName}")
	endforeach()

	set(BS_LIB_NAMES ${LIB_NAMES} PARENT_SCOPE)
	set(BS_LIB_PLATFORM_NAMES ${LIB_PLATFORM_NAMES} PARENT_SCOPE)
endfunction()

function(bs_generate_package pkg_name tier deps deps_include)
	include(CTest)
	enable_testing()

	set(CXX_STANDARD_REQUIRED ON)

	message("Found package '${pkg_name}' [${CMAKE_CURRENT_SOURCE_DIR}]")
	message("   deps: '${deps}'")
	foreach(dep ${deps})
		if(TARGET ${dep})
			get_target_property(dep_include ${dep} INTERFACE_INCLUDE_DIRECTORIES)
			list(APPEND include_deps ${dep_include})
			#message("dep: ${dep}")
			#message("dep: ${dep_include}")
		else()
			message("¤¤¤¤ WARNING ${pkg_name} was missing target ${dep}")
			list(REMOVE_ITEM deps ${dep})
		endif()
	endforeach()

	#message("include_deps: ${include_deps}")

	#### library setup ####
	set(LIBRARY_NAME "${pkg_name}")

	#### common library source ####
	file(GLOB_RECURSE include_common ${CMAKE_CURRENT_SOURCE_DIR}/include/*.h)
	SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/include PREFIX include FILES ${include_common})
	file(GLOB_RECURSE code_common ${CMAKE_CURRENT_SOURCE_DIR}/source/common/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/source/common/*.h)
	SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/source/common PREFIX src FILES ${code_common})
	file(GLOB_RECURSE test_common ${CMAKE_CURRENT_SOURCE_DIR}/tests/common/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/tests/common/*.h)
	SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/tests/common PREFIX src FILES ${test_common})

	# common library setup
	if(code_common OR include_common OR include_deps)
		add_library(${LIBRARY_NAME} STATIC ${code_common} ${include_common})
		target_include_directories(${LIBRARY_NAME} 
			PUBLIC
			${CMAKE_CURRENT_SOURCE_DIR}/include
		)
		target_link_libraries(${LIBRARY_NAME} PUBLIC ${deps})
		target_compile_definitions(${LIBRARY_NAME} PUBLIC BSYSTEM_PLATFORM_${CMAKE_SYSTEM_NAME} BSYSTEM_PLATFORM="${CMAKE_SYSTEM_NAME}" BSYSTEM_VERSION="${CMAKE_SYSTEM_VERSION}" BSYSTEM_PROCESSOR="${CMAKE_SYSTEM_PROCESSOR}")
		set_target_properties(${LIBRARY_NAME} PROPERTIES FOLDER "Packages/${tier}")

		bs_set_pedantic_flags(${LIBRARY_NAME})

		# library common tests
		if(test_common)
			set(TEST_LIBRARY_NAME "${LIBRARY_NAME}_test")
			add_executable(${TEST_LIBRARY_NAME} ${test_common})
			target_link_libraries(${TEST_LIBRARY_NAME} PUBLIC ${LIBRARY_NAME}) # library before deps, see https://stackoverflow.com/questions/1517138/trying-to-include-a-library-but-keep-getting-undefined-reference-to-messages
			target_compile_definitions(${TEST_LIBRARY_NAME} PUBLIC BSYSTEM_PLATFORM_${CMAKE_SYSTEM_NAME} BSYSTEM_PLATFORM="${CMAKE_SYSTEM_NAME}" BSYSTEM_VERSION="${CMAKE_SYSTEM_VERSION}" BSYSTEM_PROCESSOR="${CMAKE_SYSTEM_PROCESSOR}")
			add_test(NAME ${TEST_LIBRARY_NAME} COMMAND ${TEST_LIBRARY_NAME})
			set_target_properties(${TEST_LIBRARY_NAME} PROPERTIES FOLDER "Packages/${tier}")
			bs_copy_to_binary_dir("tests/data")
		endif()
	endif()

	#### platform specific library configuration ####

	if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/source/${BS_CONFIG_PLATFORM})
		# library source and headers
		file(GLOB_RECURSE include_platform ${CMAKE_CURRENT_SOURCE_DIR}/source/${BS_CONFIG_PLATFORM}/*.h)
		SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/source/${BS_CONFIG_PLATFORM} PREFIX src FILES ${include_platform})
		file(GLOB_RECURSE code_platform ${CMAKE_CURRENT_SOURCE_DIR}/source/${BS_CONFIG_PLATFORM}/*.cpp)
		SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/source/${BS_CONFIG_PLATFORM} PREFIX src FILES ${code_platform})
		file(GLOB_RECURSE test_platform ${CMAKE_CURRENT_SOURCE_DIR}/tests/${BS_CONFIG_PLATFORM}/*.cpp ${CMAKE_CURRENT_SOURCE_DIR}/tests/${BS_CONFIG_PLATFORM}/*.h)
		SOURCE_GROUP(TREE ${CMAKE_CURRENT_SOURCE_DIR}/tests/${BS_CONFIG_PLATFORM} PREFIX src FILES ${test_platform})
	
		set(LIBRARY_NAME_PLATFORM "${pkg_name}${BS_CONFIG_PLATFORM}")

		# platform library setup
		if(code_platform OR include_deps)
			add_library(${LIBRARY_NAME_PLATFORM} STATIC ${code_platform} ${include_platform})
			target_include_directories(${LIBRARY_NAME_PLATFORM} 
				PUBLIC 
				${CMAKE_CURRENT_SOURCE_DIR}/source/${BS_CONFIG_PLATFORM} 
			)
			target_link_libraries(${LIBRARY_NAME_PLATFORM} PRIVATE ${LIBRARY_NAME} ${deps})
			target_compile_definitions(${LIBRARY_NAME_PLATFORM} PUBLIC BSYSTEM_PLATFORM_${CMAKE_SYSTEM_NAME} BSYSTEM_PLATFORM="${CMAKE_SYSTEM_NAME}" BSYSTEM_VERSION="${CMAKE_SYSTEM_VERSION}" BSYSTEM_PROCESSOR="${CMAKE_SYSTEM_PROCESSOR}")
			set_target_properties(${LIBRARY_NAME_PLATFORM} PROPERTIES FOLDER "Packages/${tier}")

			bs_set_pedantic_flags(${LIBRARY_NAME_PLATFORM})

			# library tests	
			if(test_platform)
				set(TEST_LIBRARY_NAME_PLATFORM "${LIBRARY_NAME_PLATFORM}_test")
				add_executable(${TEST_LIBRARY_NAME_PLATFORM} ${test_platform})
				target_link_libraries(${TEST_LIBRARY_NAME_PLATFORM} PUBLIC ${LIBRARY_NAME_PLATFORM} ${LIBRARY_NAME} ${deps})
				target_compile_definitions(${TEST_LIBRARY_NAME_PLATFORM} PUBLIC BSYSTEM_PLATFORM_${CMAKE_SYSTEM_NAME} BSYSTEM_PLATFORM="${CMAKE_SYSTEM_NAME}" BSYSTEM_VERSION="${CMAKE_SYSTEM_VERSION}" BSYSTEM_PROCESSOR="${CMAKE_SYSTEM_PROCESSOR}")
				add_test(NAME ${TEST_LIBRARY_NAME_PLATFORM} COMMAND ${TEST_LIBRARY_NAME_PLATFORM})
				set_target_properties(${TEST_LIBRARY_NAME_PLATFORM} PROPERTIES FOLDER "Packages/${tier}")
				bs_copy_to_binary_dir("tests/data")
			endif()
		endif()
	endif()
endfunction()
