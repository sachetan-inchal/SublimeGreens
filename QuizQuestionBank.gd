extends RefCounted
class_name QuizQuestionBank

# Structure of each question entry:
# {
#   "id": String,
#   "type": String ("mcq", "fill_blank", "opengl_code", "numerical", "algorithm", "scenario"),
#   "unit": String,
#   "statement": String,
#   "options": Array[String] (exactly 4 options),
#   "correct_index": int (0..3),
#   "correct_explanation": String,
#   "incorrect_explanations": Array[String] (exactly 4 entries corresponding to options)
# }

static func get_questions_for_milestone(milestone_id: String) -> Array[Dictionary]:
	match milestone_id:
		"m1_trees":
			return _get_m1_tree_questions()
		"m3_terrain":
			return _get_m3_terrain_questions()
		"m5_multimesh":
			return _get_m5_multimesh_questions()
		"m2_camera":
			return _get_m2_camera_questions()
		"m4_aabb_lod":
			return _get_m4_lod_questions()
		"m_bonus_treasure":
			return _get_bonus_gasket_questions()
		_:
			return _get_m1_tree_questions()

# -----------------------------------------------------------------------------
# MILESTONE 1: UNIT I & V (PRIMITIVES, GEOMETRIC MODELLING, OPENGL PIPELINE)
# -----------------------------------------------------------------------------
static func _get_m1_tree_questions() -> Array[Dictionary]:
	return [
		{
			"id": "m1_q1",
			"type": "scenario",
			"unit": "Unit I & Unit V: Primitives & Geometric Modelling",
			"statement": "In Chunk.gd, a tree trunk is constructed using SurfaceTool by assembling 4 quadrilateral side faces into an ArrayMesh. How does the OpenGL/Godot rendering pipeline process each quad face?",
			"options": [
				"Decomposes each quad into 2 triangles using an index buffer (e.g. vertices 0-1-2 and 0-2-3).",
				"Renders the quad as a single arbitrary n-gon without vertex decomposition.",
				"Converts the quad into a rasterized voxel cloud on the CPU.",
				"Submits the quad directly as a continuous Bézier surface patch."
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Hardware graphics pipelines exclusively rasterize planar primitives using triangles (GL_TRIANGLES). A quad is decomposed into 2 triangles sharing an edge via indices.",
			"incorrect_explanations": [
				"",
				"Incorrect: Modern GPUs do not support arbitrary n-gons directly; all polygons must be triangulated.",
				"Incorrect: Voxel clouds are volumetric representations, not polygonal surface meshes.",
				"Incorrect: Bézier patches require parametric surface evaluation shaders, not flat quad primitives."
			]
		},
		{
			"id": "m1_q2",
			"type": "opengl_code",
			"unit": "Unit I: Graphics Programming with OpenGL",
			"statement": "In classical OpenGL, which sequence of API calls correctly renders a shaded 3D triangle with per-vertex color and surface normal attributes?",
			"options": [
				"glBegin(GL_TRIANGLES); glNormal3f(...); glColor3f(...); glVertex3f(...); (repeat 3x); glEnd();",
				"glBegin(GL_POLYGON); glVertex3f(...); glNormal3f(...); glEnd();",
				"glDrawArrays(GL_POINTS, 0, 3); glEnable(GL_LIGHTING);",
				"glutSolidSphere(1.0, 10, 10); glFlush();"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! In OpenGL immediate mode, attributes like glNormal and glColor set the current state machine before emitting each vertex with glVertex3f.",
			"incorrect_explanations": [
				"",
				"Incorrect: Emitting glVertex before glNormal assigns the normal to the NEXT vertex due to OpenGL state machine rules.",
				"Incorrect: GL_POINTS only rasterizes isolated screen pixels, not solid filled triangles.",
				"Incorrect: glutSolidSphere generates a spherical quad-mesh, not a custom 3D triangle primitive."
			]
		},
		{
			"id": "m1_q3",
			"type": "numerical",
			"unit": "Unit I: Color & RGB Models",
			"statement": "A color in 24-bit TrueColor RGB is given in normalized floating-point coordinates as (R=0.2, G=0.8, B=1.0). What are its corresponding 8-bit integer values [0 - 255]?",
			"options": [
				"R = 51, G = 204, B = 255",
				"R = 20, G = 80, B = 100",
				"R = 25, G = 128, B = 255",
				"R = 102, G = 204, B = 255"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Quantization: R = round(0.2 * 255) = 51, G = round(0.8 * 255) = 204, B = round(1.0 * 255) = 255.",
			"incorrect_explanations": [
				"",
				"Incorrect: (20, 80, 100) mistakenly treats normalized [0, 1] as percentages of 100 instead of 255.",
				"Incorrect: 0.2 * 255 = 51, not 25.",
				"Incorrect: 0.2 * 255 = 51, whereas 102 corresponds to 0.4."
			]
		},
		{
			"id": "m1_q4",
			"type": "fill_blank",
			"unit": "Unit V: Geometric Modelling",
			"statement": "In geometric modelling, the technique of constructing complex 3D shapes (like our tree's composite trunk and foliage) by combining primitive solids is called ________.",
			"options": [
				"Constructive Solid Geometry (CSG)",
				"Boundary Representation (B-Rep) Subdivision",
				"Raymarching Distance Field",
				"Barycentric Subdivision"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Constructive Solid Geometry (CSG) combines primitive geometric solids (cuboids, cylinders, spheres) to construct composite 3D objects.",
			"incorrect_explanations": [
				"",
				"Incorrect: B-Rep defines shapes purely by topology of bounding faces, edges, and vertices.",
				"Incorrect: Raymarching is an implicit volumetric rendering technique, not primitive mesh assembly.",
				"Incorrect: Barycentric subdivision is a mesh refinement scheme used in topological subdivision surfaces."
			]
		}
	]

# -----------------------------------------------------------------------------
# MILESTONE 2: UNIT I & III (TERRAIN, SURFACE NORMALS, SHADING, RASTER ALGORITHMS)
# -----------------------------------------------------------------------------
static func _get_m3_terrain_questions() -> Array[Dictionary]:
	return [
		{
			"id": "m3_q1",
			"type": "algorithm",
			"unit": "Unit III: Line Drawing & Raster Graphics",
			"statement": "In Bresenham's line algorithm for |m| < 1 (where dx > dy), if the current decision parameter is p_k >= 0, what is the update formula for the next parameter p_{k+1}?",
			"options": [
				"p_{k+1} = p_k + 2*dy - 2*dx",
				"p_{k+1} = p_k + 2*dy",
				"p_{k+1} = p_k + 2*dx - 2*dy",
				"p_{k+1} = p_k + dy/dx"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! When p_k >= 0, the upper pixel (x+1, y+1) is chosen, and the decision parameter increments by 2*dy - 2*dx.",
			"incorrect_explanations": [
				"",
				"Incorrect: p_k + 2*dy is the update when p_k < 0 (when only x increments and y stays constant).",
				"Incorrect: 2*dx - 2*dy has inverted signs and would cause unbounded divergence.",
				"Incorrect: Bresenham strictly uses integer additions and subtractions, never floating-point division dy/dx."
			]
		},
		{
			"id": "m3_q2",
			"type": "numerical",
			"unit": "Unit III: Mid-Point Circle Algorithm",
			"statement": "For the Mid-Point Circle drawing algorithm centered at the origin with radius r = 8, what is the initial decision parameter p_0?",
			"options": [
				"-7 (or 5/4 - r = -6.75)",
				"3 - 2*r = -13",
				"0",
				"8"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! For mid-point circle, p_0 = 5/4 - r. In integer arithmetic, this is rounded to 1 - r = 1 - 8 = -7.",
			"incorrect_explanations": [
				"",
				"Incorrect: 3 - 2*r is the initial parameter in classical Bresenham circle, not mid-point circle.",
				"Incorrect: Initial decision parameter depends directly on radius r and is not zero.",
				"Incorrect: p_0 cannot equal the positive radius."
			]
		},
		{
			"id": "m3_q3",
			"type": "scenario",
			"unit": "Unit I & III: Surface Normals & Shading",
			"statement": "During terrain generation in Chunk.gd, why does st.generate_normals() calculate the cross product of adjacent triangle edges (p1 - p0) x (p2 - p0)?",
			"options": [
				"To determine the perpendicular vector required for diffuse and specular illumination calculations.",
				"To calculate the horizontal velocity of the player walking on that triangle.",
				"To compress the texture UV coordinates into 16-bit integers.",
				"To invert the winding order for back-face culling."
			],
			"correct_index": 0,
			"correct_explanation": "Correct! The cross product of two non-collinear edge vectors on a planar triangle yields its normal vector, which lighting models (Lambert/Blinn-Phong) need for N · L.",
			"incorrect_explanations": [
				"",
				"Incorrect: Player velocity is handled by kinematics in Player.gd, not vertex normal cross products.",
				"Incorrect: Normals do not compress texture UVs; UVs are independent 2D texture coordinates.",
				"Incorrect: The cross product calculates surface orientation, not winding order inversion."
			]
		},
		{
			"id": "m3_q4",
			"type": "fill_blank",
			"unit": "Unit III: Filled Area Primitives",
			"statement": "When recoloring a region whose interior pixels have varying colors but are bounded by a boundary of a distinct single color, the ________ algorithm is used.",
			"options": [
				"Boundary-Fill algorithm",
				"Flood-Fill algorithm",
				"Scanline polygon fill algorithm",
				"Bresenham area filler"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Boundary-fill tests against a specified boundary color. (Flood-fill is used when replacing an interior of a single original color).",
			"incorrect_explanations": [
				"",
				"Incorrect: Flood-fill operates by replacing a connected region of a specific interior seed color, not an arbitrary multi-colored interior.",
				"Incorrect: Scanline polygon fill requires analytical vertex polygon tables (AET/ET), not raster pixel connectivity.",
				"Incorrect: Bresenham is a line/circle drawing algorithm, not an area filling algorithm."
			]
		}
	]

# -----------------------------------------------------------------------------
# MILESTONE 3: UNIT I & III (MULTIMESH, DISPLAY LISTS, AFFINE TRANSFORMATIONS)
# -----------------------------------------------------------------------------
static func _get_m5_multimesh_questions() -> Array[Dictionary]:
	return [
		{
			"id": "m5_q1",
			"type": "scenario",
			"unit": "Unit I & Unit III: GPU Instancing & Affine Transforms",
			"statement": "In Chunk.gd, MultiMeshInstance3D packs 12 floats per grass blade into a PackedFloat32Array. What mathematical structure do these 12 floats represent?",
			"options": [
				"A 3x4 affine transformation matrix (3 basis vectors for rotation/scale + 1 origin vector for translation).",
				"Three sets of 4D quaternion rotations.",
				"12 independent vertex coordinates for a cube mesh.",
				"RGBA color values across 3 mipmap levels."
			],
			"correct_index": 0,
			"correct_explanation": "Correct! In 3D graphics hardware instancing, a 3x4 matrix (Godot Transform3D: basis.x, basis.y, basis.z, and origin) defines the complete affine transform with minimal memory footprint.",
			"incorrect_explanations": [
				"",
				"Incorrect: Quaternions use 4 floats (x, y, z, w); 12 floats would be 3 separate quaternions with no translation.",
				"Incorrect: 12 floats can only store 4 3D points, whereas a cube requires 8 vertices (24 floats).",
				"Incorrect: MultiMesh transform buffers store geometry spatial matrices, not texture mipmap colors."
			]
		},
		{
			"id": "m5_q2",
			"type": "numerical",
			"unit": "Unit III: 2D Composite Transformations",
			"statement": "A point P(2, 3) is translated by Tx = 4, Ty = -1, then scaled by Sx = 2, Sy = 3 about the origin. What are the final transformed coordinates P'?",
			"options": [
				"P' = (12, 6)",
				"P' = (8, 8)",
				"P' = (6, 2)",
				"P' = (16, 9)"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Step 1 (Translation): P_t = (2 + 4, 3 - 1) = (6, 2). Step 2 (Scaling): P' = (6 * 2, 2 * 3) = (12, 6).",
			"incorrect_explanations": [
				"",
				"Incorrect: Scaling first then translating gives (2*2+4, 3*3-1) = (8, 8), which reverses transformation order.",
				"Incorrect: (6, 2) is only the intermediate translated point before scaling is applied.",
				"Incorrect: (16, 9) is mathematically incorrect."
			]
		},
		{
			"id": "m5_q3",
			"type": "opengl_code",
			"unit": "Unit I: Display Lists",
			"statement": "In classical OpenGL, what is the primary performance benefit of glNewList(id, GL_COMPILE) followed by glCallList(id)?",
			"options": [
				"Pre-compiles vertex data and state commands on GPU/driver memory, eliminating CPU-to-GPU command transfer overhead.",
				"Automatically computes Cohen-Sutherland line clipping on the CPU.",
				"Inverts the depth-buffer test to allow translucent rendering.",
				"Replaces vertex shaders with fixed-function lighting."
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Display lists store parsed commands in high-speed graphics memory, allowing repetitive objects (like trees and grass) to be drawn with a single call.",
			"incorrect_explanations": [
				"",
				"Incorrect: Clipping is handled during primitive assembly, not by display list compilation.",
				"Incorrect: Depth testing is controlled via glEnable(GL_DEPTH_TEST) and glDepthFunc, not display lists.",
				"Incorrect: Display lists store commands; they do not replace programmable shaders."
			]
		},
		{
			"id": "m5_q4",
			"type": "fill_blank",
			"unit": "Unit III: Homogeneous Coordinates",
			"statement": "In homogeneous coordinates, a 3D affine transformation matrix has the dimension ________, allowing translation, rotation, and scaling to be multiplied as composite transformations.",
			"options": [
				"4 x 4",
				"3 x 3",
				"2 x 4",
				"1 x 4"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Homogeneous coordinates represent 3D points as [x, y, z, 1]^T, requiring a 4x4 matrix so that translation can be expressed as linear matrix multiplication.",
			"incorrect_explanations": [
				"",
				"Incorrect: A 3x3 matrix can only express linear transformations (rotation, scaling, shear), but cannot represent translation.",
				"Incorrect: A 2x4 matrix cannot multiply a 3D vector.",
				"Incorrect: 1x4 is a single row vector, not a transformation operator."
			]
		}
	]

# -----------------------------------------------------------------------------
# MILESTONE 4: UNIT II & IV (INPUT, CAMERA RIG, VIEWING PIPELINE)
# -----------------------------------------------------------------------------
static func _get_m2_camera_questions() -> Array[Dictionary]:
	return [
		{
			"id": "m2_q1",
			"type": "scenario",
			"unit": "Unit IV: Viewing Pipeline & Hierarchy",
			"statement": "In Player.tscn, the camera rig is structured as Player -> Pivot -> SpringArm3D -> Camera3D. Why is pitch rotation clamped between -90 and +45 degrees in Player.gd?",
			"options": [
				"To prevent camera inversion (gimbal lock/tumbling) and avoid looking upside down.",
				"Because OpenGL projection matrices fail when rotation exceeds 45 degrees.",
				"To stop the directional sunlight from calculating negative cosine values.",
				"Because SpringArm3D only collides with geometry within positive octants."
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Euler angle pitch must be bounded to [-pi/2, +pi/2] to prevent camera flipping upside down and encountering gimbal singularity.",
			"incorrect_explanations": [
				"",
				"Incorrect: OpenGL projection matrices can handle any angle; clamping is a view controller constraint.",
				"Incorrect: Cosine evaluates normally across all angles.",
				"Incorrect: SpringArm collision uses raycasts in 360 space, independent of positive octants."
			]
		},
		{
			"id": "m2_q2",
			"type": "algorithm",
			"unit": "Unit III: Cohen-Sutherland Line Clipping",
			"statement": "In Cohen-Sutherland line clipping with a window x in [3, 10], y in [4, 9], what are the 4-bit region codes (TBRL: Top-Bottom-Right-Left) for points A(2, 11) and B(9, 2)?",
			"options": [
				"Code(A) = 1001 (Top-Left), Code(B) = 0100 (Bottom)",
				"Code(A) = 0000 (Inside), Code(B) = 0001 (Left)",
				"Code(A) = 1000 (Top), Code(B) = 0010 (Right)",
				"Code(A) = 0101 (Bottom-Left), Code(B) = 1000 (Top)"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! For A(2, 11): y=11 > 9 (Top=1), x=2 < 3 (Left=1) => 1001. For B(9, 2): y=2 < 4 (Bottom=1), 3 <= x=9 <= 10 => 0100.",
			"incorrect_explanations": [
				"",
				"Incorrect: A is outside window boundaries, so its code cannot be 0000.",
				"Incorrect: A is to the left (x=2 < 3), so Left bit must be set (1001, not 1000).",
				"Incorrect: A has y=11 > 9 (Top), not Bottom."
			]
		},
		{
			"id": "m2_q3",
			"type": "numerical",
			"unit": "Unit III: Liang-Barsky Line Clipping",
			"statement": "In Liang-Barsky clipping, line parametric equations are x = x1 + p*dx, y = y1 + p*dy. What condition immediately identifies a line segment as completely parallel to a clipping boundary?",
			"options": [
				"p_k = 0 (where p_1 = -dx, p_2 = dx, p_3 = -dy, or p_4 = dy)",
				"u_1 > u_2",
				"p_k > 0 and q_k < 0",
				"dx * dy = 1"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! If p_k = 0, the line is parallel to boundary k. If q_k < 0 as well, the line lies completely outside the boundary and can be rejected.",
			"incorrect_explanations": [
				"",
				"Incorrect: u_1 > u_2 determines that the line segment does not intersect the clipping volume, but not that it is parallel.",
				"Incorrect: p_k > 0 indicates a directed line entering or leaving a boundary, not parallel.",
				"Incorrect: dx * dy = 1 describes slope orientation, not boundary parallelism."
			]
		},
		{
			"id": "m2_q4",
			"type": "fill_blank",
			"unit": "Unit II: Event-Driven Input",
			"statement": "In input device architecture, the mouse coordinate delta (event.relative) represents the ________ of the input, while pressing the 'E' key represents the ________.",
			"options": [
				"Measure; Trigger",
				"Sample; Quantizer",
				"Trigger; Measure",
				"Poll; Interrupt"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! In logical input device terminology, 'measure' is the physical value returned (e.g. position coordinates), and 'trigger' is the event signal that initiates action.",
			"incorrect_explanations": [
				"",
				"Incorrect: Sampling and quantization are signal conversion concepts, not input interaction categories.",
				"Incorrect: The roles are reversed: relative displacement is measured; key press is triggered.",
				"Incorrect: Polling is an execution strategy, not an input device attribute pair."
			]
		}
	]

# -----------------------------------------------------------------------------
# MILESTONE 5: UNIT IV & V (AABB LOD, VISIBLE SURFACE DETECTION, COLLISION)
# -----------------------------------------------------------------------------
static func _get_m4_lod_questions() -> Array[Dictionary]:
	return [
		{
			"id": "m4_q1",
			"type": "scenario",
			"unit": "Unit IV: Visible Surface Detection & Bounding Volumes",
			"statement": "In Chunk.gd, update_grass_lod() calculates distance using the player's position clamped to the chunk's Axis-Aligned Bounding Box (AABB) rather than the chunk's center. Why?",
			"options": [
				"When inside or near the perimeter of a large chunk (32x32 scaled by 10), distance to the center would be large (~160m), causing premature LOD culling.",
				"Center distance cannot be computed in 3D vector math.",
				"AABB distance eliminates the need for depth testing in the graphics hardware.",
				"Clamping to AABB replaces the GPU vertex shader."
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Large bounding boxes have centers that may be far away even when the player is standing inside the chunk. Testing against clamped AABB gives the true minimum distance (0.0 when inside).",
			"incorrect_explanations": [
				"",
				"Incorrect: Distance to center is trivial: player_pos.distance_to(center).",
				"Incorrect: Bounding volume tests optimize CPU LOD/visibility; they do not remove GPU depth-buffer testing.",
				"Incorrect: Shaders still execute on the remaining visible instances."
			]
		},
		{
			"id": "m4_q2",
			"type": "algorithm",
			"unit": "Unit IV: Visible Surface Detection Algorithms",
			"statement": "Which visible-surface detection method operates in object space by partitioning the entire 3D scene hierarchically into convex sub-spaces using hyperplanes?",
			"options": [
				"Binary Space Partitioning (BSP) Tree method",
				"Z-Buffer (Depth-Buffer) algorithm",
				"Scan-Line algorithm",
				"Warnock Area Sub-division algorithm"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! BSP trees recursively subdivide 3D space with cutting planes to sort polygon visibility in object space from any arbitrary camera viewpoint.",
			"incorrect_explanations": [
				"",
				"Incorrect: Z-buffer algorithm operates in image space at the pixel/fragment level.",
				"Incorrect: Scan-line algorithm operates in image space by sweeping horizontal raster lines.",
				"Incorrect: Warnock algorithm recursively subdivides the 2D view-plane window into 4 quadrants."
			]
		},
		{
			"id": "m4_q3",
			"type": "numerical",
			"unit": "Unit IV: 3D Coordinate Transformations",
			"statement": "A vertex V(1, 2, 3) is rotated by 180 degrees about the Y axis. What are its transformed coordinates V'?",
			"options": [
				"V' = (-1, 2, -3)",
				"V' = (1, -2, 3)",
				"V' = (-1, -2, -3)",
				"V' = (3, 2, 1)"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Rotation by 180 deg around Y: x' = x*cos(180) + z*sin(180) = -x = -1; y' = y = 2; z' = -x*sin(180) + z*cos(180) = -z = -3.",
			"incorrect_explanations": [
				"",
				"Incorrect: (1, -2, 3) reflects Y rather than rotating around Y.",
				"Incorrect: (-1, -2, -3) represents reflection through the origin, not rotation around the Y axis.",
				"Incorrect: (3, 2, 1) swaps X and Z without correct signage."
			]
		},
		{
			"id": "m4_q4",
			"type": "fill_blank",
			"unit": "Unit V: Physical Modelling & Kinematics",
			"statement": "In Godot physics, the terrain surface is modeled using a ________ collision shape built directly from triangle arrays, while the player character is modeled with a ________ shape.",
			"options": [
				"ConcavePolygonShape3D; CapsuleShape3D",
				"BoxShape3D; PlaneShape3D",
				"HeightMapShape3D; SphereShape3D",
				"CylinderShape3D; RayShape3D"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! ConcavePolygonShape3D stores static triangle soups directly from Mesh.get_faces(), while CapsuleShape3D provides smooth traversal over uneven terrain for character movement.",
			"incorrect_explanations": [
				"",
				"Incorrect: The terrain has varying elevation and cannot be represented by a single flat PlaneShape3D or BoxShape3D.",
				"Incorrect: In our project Chunk.gd explicitly sets ConcavePolygonShape3D from faces.",
				"Incorrect: Cylinder shapes snag on terrain edges; character controllers utilize capsules with hemispherical caps."
			]
		}
	]

# -----------------------------------------------------------------------------
# BONUS MILESTONE: UNIT I (SIERPINSKI GASKET, FRACTALS & RECURSION)
# -----------------------------------------------------------------------------
static func _get_bonus_gasket_questions() -> Array[Dictionary]:
	return [
		{
			"id": "m_bonus_q1",
			"type": "algorithm",
			"unit": "Unit I: 3D Sierpinski Gasket",
			"statement": "In the recursive 3D Sierpinski Gasket program (from the CGVR Lab), when a tetrahedron with 4 vertices (A, B, C, D) is subdivided at iteration level k > 0, how many smaller tetrahedrons are generated?",
			"options": [
				"4 smaller tetrahedrons (at the 4 outer corners)",
				"8 tetrahedrons",
				"2 tetrahedrons",
				"16 tetrahedrons"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! At each recursion step, the 6 edge midpoints are computed and 4 sub-tetrahedrons are generated at corners (A, B, C, D), carving away the central octahedron.",
			"incorrect_explanations": [
				"",
				"Incorrect: Although an octahedron of volume equal to 4 tetrahedrons is removed in the middle, only 4 sub-tetrahedrons are retained.",
				"Incorrect: Binary subdivision produces 2 parts; a 3D tetrahedron subdivides into 4 corner copies.",
				"Incorrect: 16 is the count after two recursive iterations (4^2)."
			]
		},
		{
			"id": "m_bonus_q2",
			"type": "numerical",
			"unit": "Unit I: Fractal Dimension",
			"statement": "What is the theoretical Hausdorff fractal dimension of a Sierpinski triangle (2D gasket), where 3 self-similar copies of scale factor 1/2 are produced at each step?",
			"options": [
				"log(3) / log(2) ≈ 1.585",
				"log(4) / log(2) = 2.000",
				"log(2) / log(3) ≈ 0.631",
				"3 / 2 = 1.500"
			],
			"correct_index": 0,
			"correct_explanation": "Correct! Hausdorff fractal dimension D = log(N) / log(1/s) = log(3) / log(2) ≈ 1.58496.",
			"incorrect_explanations": [
				"",
				"Incorrect: log(4)/log(2) = 2 is the topological dimension of a solid 2D square.",
				"Incorrect: Dimension must be greater than 1 for a 2D fractal curve.",
				"Incorrect: Fractal dimension involves logarithmic scaling ratios, not a linear ratio 3/2."
			]
		}
	]
