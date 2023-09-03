cmake_minimum_required (VERSION 3.0.2)

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
endfunction()


function(bs_internal_set_pedantic_flags pkg_name)
	#target_compile_definitions(${LIBRARY_NAME_PLATFORM} PUBLIC cxx_std_17)
	if(MSVC)
		target_compile_options(${pkg_name} PRIVATE /W4 /WX /EHsc)
	else()
		target_compile_options(${pkg_name} PRIVATE -Wall -Wextra -Wpedantic -Werror)
	endif()
endfunction()

function(bs_copy_data relative_path)
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

function(bs_generate_package pkg_name deps)

	set(CXX_STANDARD_REQUIRED ON)

	message("Found package '${pkg_name}' [${CMAKE_CURRENT_SOURCE_DIR}]")
	message("   deps: '${deps}'")
	foreach(dep ${deps})
		if(TARGET ${dep})
			get_target_property(dep_include ${dep} INTERFACE_INCLUDE_DIRECTORIES)
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
			bs_copy_data("tests/data")
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
				bs_copy_data("tests/data")
			endif()
		endif()
	endif()
endfunction()
