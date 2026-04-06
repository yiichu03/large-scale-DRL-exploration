import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, ExecuteProcess, IncludeLaunchDescription, OpaqueFunction
from launch.event_handlers import OnProcessExit
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch.actions import RegisterEventHandler
from launch_ros.actions import Node


def declare_world_action(context, world_name):
    world_name_str = str(world_name.perform(context))
    declare_world = DeclareLaunchArgument(
        "world",
        default_value=[os.path.join(get_package_share_directory("vehicle_simulator"), "world", world_name_str + ".world")],
        description="",
    )
    return [declare_world]


def generate_launch_description():
    assets_dir = os.path.join(os.path.dirname(__file__), "..", "assets")
    scripts_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    lidar_urdf_path = os.path.abspath(os.path.join(assets_dir, "vlp16_lidar.urdf"))
    camera_urdf_path = os.path.abspath(os.path.join(assets_dir, "camera.urdf"))
    spawn_helper_path = os.path.join(scripts_dir, "spawn_entity_when_ready.sh")

    with open(lidar_urdf_path, "r", encoding="utf-8") as f:
        lidar_description = f.read()

    sensor_offset_x = LaunchConfiguration("sensorOffsetX")
    sensor_offset_y = LaunchConfiguration("sensorOffsetY")
    vehicle_height = LaunchConfiguration("vehicleHeight")
    camera_offset_z = LaunchConfiguration("cameraOffsetZ")
    vehicle_x = LaunchConfiguration("vehicleX")
    vehicle_y = LaunchConfiguration("vehicleY")
    vehicle_z = LaunchConfiguration("vehicleZ")
    terrain_z = LaunchConfiguration("terrainZ")
    vehicle_yaw = LaunchConfiguration("vehicleYaw")
    terrain_voxel_size = LaunchConfiguration("terrainVoxelSize")
    ground_height_thre = LaunchConfiguration("groundHeightThre")
    adjust_z = LaunchConfiguration("adjustZ")
    terrain_radius_z = LaunchConfiguration("terrainRadiusZ")
    min_terrain_point_num_z = LaunchConfiguration("minTerrainPointNumZ")
    smooth_rate_z = LaunchConfiguration("smoothRateZ")
    adjust_incl = LaunchConfiguration("adjustIncl")
    terrain_radius_incl = LaunchConfiguration("terrainRadiusIncl")
    min_terrain_point_num_incl = LaunchConfiguration("minTerrainPointNumIncl")
    smooth_rate_incl = LaunchConfiguration("smoothRateIncl")
    incl_fitting_thre = LaunchConfiguration("InclFittingThre")
    max_incl = LaunchConfiguration("maxIncl")
    pause = LaunchConfiguration("pause")
    use_sim_time = LaunchConfiguration("use_sim_time")
    gui = LaunchConfiguration("gui")
    record = LaunchConfiguration("record")
    verbose = LaunchConfiguration("verbose")
    world_name = LaunchConfiguration("world_name")
    cmd_vel_topic = LaunchConfiguration("cmd_vel_topic")

    declare_sensor_offset_x = DeclareLaunchArgument("sensorOffsetX", default_value="0.0", description="")
    declare_sensor_offset_y = DeclareLaunchArgument("sensorOffsetY", default_value="0.0", description="")
    declare_vehicle_height = DeclareLaunchArgument("vehicleHeight", default_value="0.75", description="")
    declare_camera_offset_z = DeclareLaunchArgument("cameraOffsetZ", default_value="0.0", description="")
    declare_vehicle_x = DeclareLaunchArgument("vehicleX", default_value="0.0", description="")
    declare_vehicle_y = DeclareLaunchArgument("vehicleY", default_value="0.0", description="")
    declare_vehicle_z = DeclareLaunchArgument("vehicleZ", default_value="0.0", description="")
    declare_terrain_z = DeclareLaunchArgument("terrainZ", default_value="0.0", description="")
    declare_vehicle_yaw = DeclareLaunchArgument("vehicleYaw", default_value="0.0", description="")
    declare_terrain_voxel_size = DeclareLaunchArgument("terrainVoxelSize", default_value="0.05", description="")
    declare_ground_height_thre = DeclareLaunchArgument("groundHeightThre", default_value="0.1", description="")
    declare_adjust_z = DeclareLaunchArgument("adjustZ", default_value="true", description="")
    declare_terrain_radius_z = DeclareLaunchArgument("terrainRadiusZ", default_value="1.0", description="")
    declare_min_terrain_point_num_z = DeclareLaunchArgument("minTerrainPointNumZ", default_value="5", description="")
    declare_smooth_rate_z = DeclareLaunchArgument("smoothRateZ", default_value="0.5", description="")
    declare_adjust_incl = DeclareLaunchArgument("adjustIncl", default_value="true", description="")
    declare_terrain_radius_incl = DeclareLaunchArgument("terrainRadiusIncl", default_value="2.0", description="")
    declare_min_terrain_point_num_incl = DeclareLaunchArgument("minTerrainPointNumIncl", default_value="200", description="")
    declare_smooth_rate_incl = DeclareLaunchArgument("smoothRateIncl", default_value="0.5", description="")
    declare_incl_fitting_thre = DeclareLaunchArgument("InclFittingThre", default_value="0.2", description="")
    declare_max_incl = DeclareLaunchArgument("maxIncl", default_value="30.0", description="")
    declare_pause = DeclareLaunchArgument("pause", default_value="false", description="")
    declare_use_sim_time = DeclareLaunchArgument("use_sim_time", default_value="false", description="")
    declare_gui = DeclareLaunchArgument("gui", default_value="false", description="")
    declare_record = DeclareLaunchArgument("record", default_value="false", description="")
    declare_verbose = DeclareLaunchArgument("verbose", default_value="false", description="")
    declare_world_name = DeclareLaunchArgument("world_name", default_value="garage", description="")
    declare_cmd_vel_topic = DeclareLaunchArgument("cmd_vel_topic", default_value="/cmd_vel", description="")

    start_lidar_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        name="robot_state_publisher",
        output="screen",
        parameters=[{"use_sim_time": use_sim_time, "robot_description": lidar_description}],
    )

    spawn_lidar = ExecuteProcess(
        cmd=[spawn_helper_path, "-entity", "lidar", "-topic", "robot_description"],
        output="screen",
    )

    robot_sdf = os.path.join(get_package_share_directory("vehicle_simulator"), "urdf", "robot.sdf")
    spawn_robot = ExecuteProcess(
        cmd=[spawn_helper_path, "-file", robot_sdf, "-entity", "robot"],
        output="screen",
    )

    spawn_camera = ExecuteProcess(
        cmd=[spawn_helper_path, "-file", camera_urdf_path, "-entity", "camera"],
        output="screen",
    )

    start_gazebo = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(os.path.join(get_package_share_directory("gazebo_ros"), "launch", "gazebo.launch.py")),
        launch_arguments={
            "world": LaunchConfiguration("world"),
            "gui": gui,
            "pause": pause,
            "record": record,
            "verbose": verbose,
        }.items(),
    )

    start_vehicle_simulator = Node(
        package="vehicle_simulator",
        executable="vehicleSimulator",
        parameters=[
            {
                "use_gazebo_time": False,
                "sensorOffsetX": sensor_offset_x,
                "sensorOffsetY": sensor_offset_y,
                "vehicleHeight": vehicle_height,
                "cameraOffsetZ": camera_offset_z,
                "vehicleX": vehicle_x,
                "vehicleY": vehicle_y,
                "vehicleZ": vehicle_z,
                "terrainZ": terrain_z,
                "vehicleYaw": vehicle_yaw,
                "terrainVoxelSize": terrain_voxel_size,
                "groundHeightThre": ground_height_thre,
                "adjustZ": adjust_z,
                "terrainRadiusZ": terrain_radius_z,
                "minTerrainPointNumZ": min_terrain_point_num_z,
                "smoothRateZ": smooth_rate_z,
                "adjustIncl": adjust_incl,
                "terrainRadiusIncl": terrain_radius_incl,
                "minTerrainPointNumIncl": min_terrain_point_num_incl,
                "smoothRateIncl": smooth_rate_incl,
                "InclFittingThre": incl_fitting_thre,
                "maxIncl": max_incl,
                "use_sim_time": use_sim_time,
            }
        ],
        remappings=[
            ("/cmd_vel", cmd_vel_topic),
        ],
        output="screen",
    )

    ld = LaunchDescription()
    ld.add_action(declare_sensor_offset_x)
    ld.add_action(declare_sensor_offset_y)
    ld.add_action(declare_vehicle_height)
    ld.add_action(declare_camera_offset_z)
    ld.add_action(declare_vehicle_x)
    ld.add_action(declare_vehicle_y)
    ld.add_action(declare_vehicle_z)
    ld.add_action(declare_terrain_z)
    ld.add_action(declare_vehicle_yaw)
    ld.add_action(declare_terrain_voxel_size)
    ld.add_action(declare_ground_height_thre)
    ld.add_action(declare_adjust_z)
    ld.add_action(declare_terrain_radius_z)
    ld.add_action(declare_min_terrain_point_num_z)
    ld.add_action(declare_smooth_rate_z)
    ld.add_action(declare_adjust_incl)
    ld.add_action(declare_terrain_radius_incl)
    ld.add_action(declare_min_terrain_point_num_incl)
    ld.add_action(declare_smooth_rate_incl)
    ld.add_action(declare_incl_fitting_thre)
    ld.add_action(declare_max_incl)
    ld.add_action(declare_pause)
    ld.add_action(declare_use_sim_time)
    ld.add_action(declare_gui)
    ld.add_action(declare_record)
    ld.add_action(declare_verbose)
    ld.add_action(declare_world_name)
    ld.add_action(declare_cmd_vel_topic)
    ld.add_action(OpaqueFunction(function=declare_world_action, args=[world_name]))

    ld.add_action(start_gazebo)
    ld.add_action(start_lidar_state_publisher)
    ld.add_action(spawn_lidar)
    ld.add_action(
        RegisterEventHandler(
            OnProcessExit(
                target_action=spawn_lidar,
                on_exit=[spawn_robot],
            )
        )
    )
    ld.add_action(
        RegisterEventHandler(
            OnProcessExit(
                target_action=spawn_robot,
                on_exit=[spawn_camera],
            )
        )
    )
    ld.add_action(
        RegisterEventHandler(
            OnProcessExit(
                target_action=spawn_camera,
                on_exit=[start_vehicle_simulator],
            )
        )
    )
    return ld
