################################################################################
# Set minimum required version of cmake, project name and compile options
################################################################################
cmake_minimum_required(VERSION 3.16)
project(om_impedance_controller LANGUAGES CXX)

if(CMAKE_CXX_COMPILER_ID MATCHES "(GNU|Clang)")
  add_compile_options(-Wall -Wextra -Wpedantic -Werror=unused-but-set-variable
                      -Werror=return-type -Werror=shadow -Werror=format -Werror=range-loop-construct
                      -Werror=missing-braces)
endif()

set(THIS_PACKAGE_INCLUDE_DEPENDS
  angles
  control_msgs
  control_toolbox
  controller_interface
  generate_parameter_library
  hardware_interface
  pluginlib
  rclcpp
  rclcpp_lifecycle
  realtime_tools
  rsl
  tl_expected
  urdf
  kdl_parser
  orocos_kdl
  std_srvs
)

################################################################################
# Find ament packages and libraries for ament and system dependencies
################################################################################
find_package(ament_cmake REQUIRED)
find_package(backward_ros REQUIRED)
foreach(Dependency IN ITEMS ${THIS_PACKAGE_INCLUDE_DEPENDS})
  find_package(${Dependency} REQUIRED)
endforeach()

################################################################################
# Build
################################################################################
generate_parameter_library(impedance_controller_parameters
  src/impedance_controller_parameters.yaml
)

add_library(impedance_controller SHARED
  src/impedance_controller.cpp
)
target_compile_features(impedance_controller PUBLIC cxx_std_17)
target_include_directories(impedance_controller PUBLIC
  $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include/impedance_controller>
)
target_link_libraries(impedance_controller PUBLIC
  controller_interface::controller_interface
  hardware_interface::mock_components
  pluginlib::pluginlib
  rclcpp::rclcpp
  rclcpp_lifecycle::rclcpp_lifecycle
  realtime_tools::realtime_tools
  ${backward_ros_LIBRARIES}
  ${tl_expected_LIBRARIES}
  ${urdf_LIBRARIES}
  ${kdl_parser_TARGETS}
  ${orocos_kdl_TARGETS}
  impedance_controller_parameters
)

# Causes the visibility macros to use dllexport rather than dllimport,
# which is appropriate when building the dll but not consuming it.
target_compile_definitions(impedance_controller PRIVATE "impedance_controller_BUILDING_DLL" "_USE_MATH_DEFINES")
target_link_libraries(impedance_controller PUBLIC ${std_srvs_TARGETS})
pluginlib_export_plugin_description_file(controller_interface impedance_plugin.xml)

################################################################################
# Install
################################################################################
install(
  DIRECTORY include/
  DESTINATION include/impedance_controller
)
install(TARGETS
    impedance_controller
    impedance_controller_parameters
  EXPORT export_impedance_controller
  RUNTIME DESTINATION bin
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
)

################################################################################
# Macro for ament package
################################################################################
ament_export_targets(export_impedance_controller HAS_LIBRARY_TARGET)
ament_export_dependencies(${THIS_PACKAGE_INCLUDE_DEPENDS})
ament_package()
