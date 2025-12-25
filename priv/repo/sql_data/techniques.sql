-- techniques
-- Generated at 2025-12-25 04:08:55.560315Z
-- Rows: 11

INSERT INTO techniques (id, name, inserted_at, updated_at, orientation_name, created_by_id, updated_by_id, sub_position_name, action_name) VALUES
  (1, 'Arm Drag To The Back', '2025-12-23T02:46:33.705381', '2025-12-23T02:46:33.705381', 'bottom', 1, 1, 'butterfly_guard', 'transitions'),
  (2, 'Butterfly Sweep', '2025-12-23T03:57:58.695678', '2025-12-23T03:57:58.695678', 'bottom', 1, 1, 'butterfly_guard', 'sweeps'),
  (3, 'Back Take From Mount', '2025-12-25T02:13:57.703335', '2025-12-25T02:13:57.703335', 'top', 1, 1, 'low_mount', 'transitions'),
  (4, 'Scissor Sweep From Closed Guard', '2025-12-25T02:16:20.097588', '2025-12-25T02:16:20.097588', 'bottom', 1, 1, 'closed_guard', 'sweeps'),
  (5, 'Double Ankle Sweep From Closed Guard', '2025-12-25T02:24:02.321499', '2025-12-25T02:24:02.321499', 'bottom', 1, 1, 'closed_guard', 'sweeps'),
  (6, 'Low Elbow Guillotine From Closed Guard', '2025-12-25T02:28:53.979361', '2025-12-25T02:28:53.979361', 'bottom', 1, 1, 'closed_guard', 'submissions'),
  (7, 'Rear Naked Choke From The Back', '2025-12-25T03:11:47.108338', '2025-12-25T03:11:47.108338', 'superior', 1, 1, 'back_mount', 'submissions'),
  (8, 'Farside Armbar From Side Control', '2025-12-25T03:19:14.001422', '2025-12-25T03:19:14.001422', 'top', 1, 1, 'standard_side_control', 'submissions'),
  (9, 'Cross Collar Choke From The Mount', '2025-12-25T03:21:27.348928', '2025-12-25T03:21:27.348928', 'top', 1, 1, 'high_mount', 'submissions'),
  (10, 'Berimbolo From De La Riva', '2025-12-25T03:29:24.818904', '2025-12-25T03:29:24.818904', 'bottom', 1, 1, 'de_la_riva_guard', 'transitions'),
  (11, 'Body Triangle Escape', '2025-12-25T03:31:42.715163', '2025-12-25T03:31:42.715163', 'inferior', 1, 1, 'back_mount', 'escapes')
ON CONFLICT DO NOTHING;
