import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.launch_description_sources import FrontendLaunchDescriptionSource, PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    world_name = LaunchConfiguration("world_name")
    vehicle_height = LaunchConfiguration("vehicleHeight")
    camera_offset_z = LaunchConfiguration("cameraOffsetZ")
    vehicle_x = LaunchConfiguration("vehicleX")
    vehicle_y = LaunchConfiguration("vehicleY")
    vehicle_z = LaunchConfiguration("vehicleZ")
    terrain_z = LaunchConfiguration("terrainZ")
    vehicle_yaw = LaunchConfiguration("vehicleYaw")
    gazebo_gui = LaunchConfiguration("gazebo_gui")
    check_terrain_conn = LaunchConfiguration("checkTerrainConn")
    cmd_vel_topic = LaunchConfiguration("cmd_vel_topic")
    start_joy = LaunchConfiguration("start_joy")

    declare_world_name = DeclareLaunchArgument("world_name", default_value="garage", description="")
    declare_vehicle_height = DeclareLaunchArgument("vehicleHeight", default_value="0.75", description="")
    declare_camera_offset_z = DeclareLaunchArgument("cameraOffsetZ", default_value="0.0", description="")
    declare_vehicle_x = DeclareLaunchArgument("vehicleX", default_value="0.0", description="")
    declare_vehicle_y = DeclareLaunchArgument("vehicleY", default_value="0.0", description="")
    declare_vehicle_z = DeclareLaunchArgument("vehicleZ", default_value="0.0", description="")
    declare_terrain_z = DeclareLaunchArgument("terrainZ", default_value="0.0", description="")
    declare_vehicle_yaw = DeclareLaunchArgument("vehicleYaw", default_value="0.0", description="")
    declare_gazebo_gui = DeclareLaunchArgument("gazebo_gui", default_value="false", description="")
    declare_check_terrain_conn = DeclareLaunchArgument("checkTerrainConn", default_value="true", description="")
    declare_cmd_vel_topic = DeclareLaunchArgument("cmd_vel_topic", default_value="/cmd_vel_stamped", description="")
    declare_start_joy = DeclareLaunchArgument("start_joy", default_value="false", description="")

    start_terrain_analysis = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(
            os.path.join(get_package_share_directory("terrain_analysis"), "launch", "terrain_analysis.launch")
        )
    )

    start_terrain_analysis_ext = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(
            os.path.join(get_package_share_directory("terrain_analysis_ext"), "launch", "terrain_analysis_ext.launch")
        ),
        launch_arguments={"checkTerrainConn": check_terrain_conn}.items(),
    )

    start_vehicle_simulator = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(os.path.dirname(__file__), "official_vehicle_simulator_no_xacro.launch.py")
        ),
        launch_arguments={
            "world_name": world_name,
            "vehicleHeight": vehicle_height,
            "cameraOffsetZ": camera_offset_z,
            "vehicleX": vehicle_x,
            "vehicleY": vehicle_y,
            "vehicleZ": vehicle_z,
            "terrainZ": terrain_z,
            "vehicleYaw": vehicle_yaw,
            "gui": gazebo_gui,
            "cmd_vel_topic": cmd_vel_topic,
        }.items(),
    )

    start_sensor_scan_generation = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(
            os.path.join(get_package_share_directory("sensor_scan_generation"), "launch", "sensor_scan_generation.launch")
        )
    )

    joy_node = Node(
        package="joy",
        executable="joy_node",
        name="ps3_joy",
        output="screen",
        parameters=[
            {
                "dev": "/dev/input/js0",
                "deadzone": 0.12,
                "autorepeat_rate": 0.0,
            }
        ],
        condition=IfCondition(start_joy),
    )

    ld = LaunchDescription()
    ld.add_action(declare_world_name)
    ld.add_action(declare_vehicle_height)
    ld.add_action(declare_camera_offset_z)
    ld.add_action(declare_vehicle_x)
    ld.add_action(declare_vehicle_y)
    ld.add_action(declare_vehicle_z)
    ld.add_action(declare_terrain_z)
    ld.add_action(declare_vehicle_yaw)
    ld.add_action(declare_gazebo_gui)
    ld.add_action(declare_check_terrain_conn)
    ld.add_action(declare_cmd_vel_topic)
    ld.add_action(declare_start_joy)

    ld.add_action(start_terrain_analysis)
    ld.add_action(start_terrain_analysis_ext)
    ld.add_action(start_vehicle_simulator)
    ld.add_action(start_sensor_scan_generation)
    ld.add_action(joy_node)

    return ld
