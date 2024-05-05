import pyrealsense2 as rs

from pprint import pprint
from collections import namedtuple
from functools import partial

attrs = [
    'acceleration',
    'angular_acceleration',
    'angular_velocity',
    'mapper_confidence',
    'rotation',
    'tracker_confidence',
    'translation',
    'velocity',
    ]
Pose = namedtuple('Pose', attrs)

def main():
    pipeline = rs.pipeline()
    cfg = rs.config()
    # if only pose stream is enabled, fps is higher (202 vs 30)
    print("enable pose stream")
    cfg.enable_stream(rs.stream.pose)
    pipeline.start(cfg)
    poses = []
    print("start loop")
    try:
        while True:
            frames = pipeline.wait_for_frames()
            pose_frame = frames.get_pose_frame()
            if pose_frame:
                pose = pose_frame.get_pose_data()
                n = pose_frame.get_frame_number()
                timestamp = pose_frame.get_timestamp()
                p = Pose(*map(partial(getattr, pose), attrs))
                poses.append((n, timestamp, p))
                print(f"Translation: x: {p.translation.x:+.5f} y: {p.translation.y:+.5f} z: {p.translation.z:+.5f}")
                # if len(poses) == 100:
                #     return
    finally:
        pipeline.stop()
        duration = (poses[-1][1]-poses[0][1])/1000
        print(f'start: {poses[0][1]}')
        print(f'end:   {poses[-1][1]}')
        print(f'duration: {duration}s')
        print(f'fps: {len(poses)/duration}')


if __name__ == "__main__":
    main()