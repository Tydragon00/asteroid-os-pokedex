add_library(${CMAKE_PROJECT_NAME} main.cpp resources.qrc)
find_package(Qt5 COMPONENTS Sql REQUIRED)

target_link_libraries(${CMAKE_PROJECT_NAME} PUBLIC
	AsteroidApp)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE Qt5::Sql)
install(TARGETS ${CMAKE_PROJECT_NAME}
	DESTINATION ${CMAKE_INSTALL_LIBDIR})
