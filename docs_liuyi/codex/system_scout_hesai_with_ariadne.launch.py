"""
system_scout_hesai_with_ariadne.launch.py
=========================================

这是一个给 `autonomy_stack_mecanum_wheel_platform` 使用的 ARiADNE 接入草案。

用途：
- 作为后续真正落到 `vehicle_simulator/launch/` 目录中的参考版本
- 目标是替换当前 TARE 高层探索器，仅保留 `/way_point` 接口不变

当前状态：
- 这是文档型草案，不保证直接可运行
- 目的是把“最小改造方案”固化成一个清晰的 launch 结构

最关键的接入点：
- 保留：FAST-LIO2 / relay / sensor_scan_generation / terrain_analysis / localPlanner
- 删除：tare_planner_node
- 新增：octomap_server_node + rl_planner
- 注意：ARiADNE 的 `base_frame` 需要从官方默认的 `sensor` 改成 `sensor_at_scan`
"""

import os
from datetime import datetime

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, LogInfo
from launch.launch_description_sources import FrontendLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node, SetParameter


def generate_launch_description():
    use_sim_time = LaunchConfiguration('use_sim_time')
    sensorOffsetX = LaunchConfiguration('sensorOffsetX')
    sensorOffsetY = LaunchConfiguration('sensorOffsetY')
    cameraOffsetZ = LaunchConfiguration('cameraOffsetZ')
    vehicleX = LaunchConfiguration('vehicleX')
    vehicleY = LaunchConfiguration('vehicleY')
    maxSpeed = LaunchConfiguration('maxSpeed')
    checkTerrainConn = LaunchConfiguration('checkTerrainConn')
    enableDebugLog = LaunchConfiguration('enableDebugLog')
    debugLogDir = LaunchConfiguration('debugLogDir')
    debugLogDecimation = LaunchConfiguration('debugLogDecimation')
    gravityLevelQx = LaunchConfiguration('gravityLevelQx')
    gravityLevelQy = LaunchConfiguration('gravityLevelQy')
    gravityLevelQz = LaunchConfiguration('gravityLevelQz')
    gravityLevelQw = LaunchConfiguration('gravityLevelQw')

    workspace_root = os.path.dirname(
        os.path.dirname(
            os.path.dirname(
                os.path.dirname(get_package_share_directory('vehicle_simulator')))))
    default_debug_log_dir = os.path.join(
        workspace_root,
        'runtime_logs',
        'navigation_debug',
        datetime.now().strftime('%Y%m%d_%H%M%S'))

    declare_use_sim_time = DeclareLaunchArgument('use_sim_time', default_value='false')
    declare_sensorOffsetX = DeclareLaunchArgument('sensorOffsetX', default_value='0.0')
    declare_sensorOffsetY = DeclareLaunchArgument('sensorOffsetY', default_value='0.0')
    declare_cameraOffsetZ = DeclareLaunchArgument('cameraOffsetZ', default_value='0.2')
    declare_vehicleX = DeclareLaunchArgument('vehicleX', default_value='0.0')
    declare_vehicleY = DeclareLaunchArgument('vehicleY', default_value='0.0')
    declare_maxSpeed = DeclareLaunchArgument('maxSpeed', default_value='0.5')
    declare_checkTerrainConn = DeclareLaunchArgument('checkTerrainConn', default_value='true')
    declare_enable_debug_log = DeclareLaunchArgument('enableDebugLog', default_value='true')
    declare_debug_log_dir = DeclareLaunchArgument('debugLogDir', default_value=default_debug_log_dir)
    declare_debug_log_decimation = DeclareLaunchArgument('debugLogDecimation', default_value='10')
    declare_gravity_level_qx = DeclareLaunchArgument('gravityLevelQx', default_value='-0.004276')
    declare_gravity_level_qy = DeclareLaunchArgument('gravityLevelQy', default_value='0.043092')
    declare_gravity_level_qz = DeclareLaunchArgument('gravityLevelQz', default_value='0.000000')
    declare_gravity_level_qw = DeclareLaunchArgument('gravityLevelQw', default_value='0.999062')

    fastlio_config_path = os.path.join(
        get_package_share_directory('fast_lio'), 'config')

    start_fastlio = Node(
        package='fast_lio',
        executable='fastlio_mapping',
        name='fastlio_mapping',
        parameters=[
            os.path.join(fastlio_config_path, 'hesai_xt32.yaml'),
            {'use_sim_time': use_sim_time},
        ],
        remappings=[
            ('/Odometry', '/state_estimation_raw'),
            ('/cloud_registered', '/registered_scan_raw'),
            ('/path', '/fastlio_path'),
        ],
        output='screen',
    )

    start_registered_scan_relay = Node(
        package='vehicle_simulator',
        executable='registeredScanFrameRelay',
        name='registered_scan_frame_relay',
        parameters=[{
            'gravity_level_qx': gravityLevelQx,
            'gravity_level_qy': gravityLevelQy,
            'gravity_level_qz': gravityLevelQz,
            'gravity_level_qw': gravityLevelQw,
        }],
        output='screen',
    )

    start_odom_relay = Node(
        package='vehicle_simulator',
        executable='odom_frame_relay.py',
        name='odom_frame_relay',
        parameters=[{
            'gravity_level_qx': gravityLevelQx,
            'gravity_level_qy': gravityLevelQy,
            'gravity_level_qz': gravityLevelQz,
            'gravity_level_qw': gravityLevelQw,
        }],
        output='screen',
    )

    start_sensor_scan_generation = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(os.path.join(
            get_package_share_directory('sensor_scan_generation'),
            'launch', 'sensor_scan_generation.launch')),
    )

    start_terrain_analysis = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(os.path.join(
            get_package_share_directory('terrain_analysis'),
            'launch', 'terrain_analysis.launch')),
    )

    # ARiADNE 本身不需要 terrain_analysis_ext，但首轮最小替换时可先保留。
    start_terrain_analysis_ext = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(os.path.join(
            get_package_share_directory('terrain_analysis_ext'),
            'launch', 'terrain_analysis_ext.launch')),
        launch_arguments={'checkTerrainConn': checkTerrainConn}.items(),
    )

    start_local_planner = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(os.path.join(
            get_package_share_directory('local_planner'),
            'launch', 'local_planner.launch')),
        launch_arguments={
            'config': 'standard',
            'realRobot': 'false',
            'sensorOffsetX': sensorOffsetX,
            'sensorOffsetY': sensorOffsetY,
            'cameraOffsetZ': cameraOffsetZ,
            'goalX': vehicleX,
            'goalY': vehicleY,
            'maxSpeed': maxSpeed,
            'twoWayDrive': 'true',
            'autonomyMode': 'true',
            'vehicleLength': '0.70',
            'vehicleWidth': '0.60',
            'enableDebugLog': enableDebugLog,
            'debugLogDir': debugLogDir,
            'debugLogDecimation': debugLogDecimation,
        }.items(),
    )

    # 下面两个包名假定 ARiADNE 已经以 ROS2 包的形式出现在当前工作区中。
    # 如果是独立 overlay 工作区，需要在真正落地时决定是：
    # 1. 把包并入当前工作区；或
    # 2. 通过 source overlay 的方式统一环境。
    start_octomap = Node(
        package='octomap_server',
        executable='octomap_server_node',
        name='octomap',
        output='screen',
        remappings=[('cloud_in', 'sensor_scan')],
        parameters=[
            {'frame_id': 'map'},
            # 关键：不要沿用官方默认 sensor，应改成当前系统的 sensor_at_scan
            {'base_frame_id': 'sensor_at_scan'},
            {'resolution': 0.4},
            {'occupancy_min_z': 0.0},
            {'occupancy_max_z': 1.2},
            {'sensor_model.max_range': 20.0},
            {'sensor_model.hit': 1.0},
            {'sensor_model.miss': 0.45},
            {'sensor_model.max': 1.0},
            {'sensor_model.min': 0.2},
        ],
    )

    start_ariadne = Node(
        package='rl_planner',
        executable='rl_planner',
        name='rl_planner',
        output='screen',
        emulate_tty=True,
        parameters=[
            {'publish_graph': False},
            {'node_resolution': 2.0},
            {'sensor_range': 20.0},
            {'utility_range_factor': 0.5},
            {'min_utility': 3},
            {'frontier_downsample_factor': 1},
            {'map_resolution': 0.4},
            {'waypoint_threshold': 2.0},
            {'next_waypoint_threshold': 4.0},
            {'hard_update_threshold': 10.0},
            {'frontier_cluster_range': 10.0},
            {'enable_save_mode': False},
            {'enable_dstarlite': False},
            {'replanning_frequency': 2.5},
            {'use_sim_time': use_sim_time},
        ],
    )

    start_visualization_tools = IncludeLaunchDescription(
        FrontendLaunchDescriptionSource(os.path.join(
            get_package_share_directory('visualization_tools'),
            'launch', 'visualization_tools.launch')),
        launch_arguments={'world_name': 'real_world'}.items(),
    )

    start_rviz = Node(
        package='rviz2',
        executable='rviz2',
        name='rviz2',
        arguments=['-d', os.path.join(
            get_package_share_directory('vehicle_simulator'),
            'rviz', 'vehicle_simulator.rviz')],
        output='screen',
    )

    tf_map_to_camera_init = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        name='tf_map_to_camera_init',
        arguments=['0', '0', '0', '-0.523215', '0.518939', '-0.480123', '0.475847', 'map', 'camera_init'],
    )

    tf_body_to_sensor = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        name='tf_body_to_sensor',
        arguments=['0', '0', '0', '0.5', '-0.5', '0.5', '0.5', 'body', 'sensor'],
    )

    tf_sensor_at_scan_to_vehicle = Node(
        package='tf2_ros',
        executable='static_transform_publisher',
        name='tf_sensor_at_scan_to_vehicle',
        arguments=['0', '0', '0', '0', '0', '0', '1', 'sensor_at_scan', 'vehicle'],
    )

    ld = LaunchDescription()

    ld.add_action(declare_use_sim_time)
    ld.add_action(declare_sensorOffsetX)
    ld.add_action(declare_sensorOffsetY)
    ld.add_action(declare_cameraOffsetZ)
    ld.add_action(declare_vehicleX)
    ld.add_action(declare_vehicleY)
    ld.add_action(declare_maxSpeed)
    ld.add_action(declare_checkTerrainConn)
    ld.add_action(declare_enable_debug_log)
    ld.add_action(declare_debug_log_dir)
    ld.add_action(declare_debug_log_decimation)
    ld.add_action(declare_gravity_level_qx)
    ld.add_action(declare_gravity_level_qy)
    ld.add_action(declare_gravity_level_qz)
    ld.add_action(declare_gravity_level_qw)
    ld.add_action(LogInfo(msg=['Navigation debug logs: ', debugLogDir]))

    ld.add_action(SetParameter(name='use_sim_time', value=use_sim_time))

    ld.add_action(tf_map_to_camera_init)
    ld.add_action(tf_body_to_sensor)
    ld.add_action(tf_sensor_at_scan_to_vehicle)

    ld.add_action(start_fastlio)
    ld.add_action(start_registered_scan_relay)
    ld.add_action(start_odom_relay)
    ld.add_action(start_sensor_scan_generation)
    ld.add_action(start_terrain_analysis)
    ld.add_action(start_terrain_analysis_ext)
    ld.add_action(start_local_planner)
    ld.add_action(start_octomap)
    ld.add_action(start_ariadne)
    ld.add_action(start_visualization_tools)
    ld.add_action(start_rviz)

    return ld

