# Physnake
**A physics-based snake game (Godot 4 demo)**

I always wanted to know how a physics-based snake game could look and feel. For a two-day project the gameplay turned out to be kinda fun.

As a beginner using Godot, I wanted to try out a few techniques:
- Vector-like 2D graphics using only polygons (circle shapes and bezier shapes), for perfect scalability and sharp edges. While Godot can import SVG, it just converts SVG to textures, with less then optimal scaling quality (you may import with mipmap option and downscale, but it's still kinda blurry compared to mesh contures). Polygons are rendered perfectly, but Godot is missing higher level tooling for generating polygons. So I've created tool scripts to generate polygons procedurally.
- Creating nodes and joints dynamically using script. The `DampedSpringJoint2D` that is used to connect the snake segments turned out to be less intuitive, as it requires us to define a starting point, an angle and a length, instead of simply two points to connect to.
- Custom collision detection to find a free spot for spawning food. This works well using `ShapeCast2D`.
- Explosions using GPU particles. This turned out really easy, after finding the right particle settings.
- Affecting physics objects by explosions. Note how the snake gets thrown around and ripped apart by the explosions, which randomly separates the joints. This can create nice chain reactions. See "components/obstacle.gd".
- Marking gdscripts as `@tool` to render game objects in the editor in the same way as in-game. This is required when a gdscript defines exported properties that change the look of the game object (e. g. when changing the "obstacle_size" property of an obstacle instance, the Godot editor immediately updates and draws the obstacle in the correct size).

![start](screenshots/start.png "Start")
![gameplay](screenshots/gameplay.png "Gameplay")
![hardmode](screenshots/hardmode.png "Hard Mode")
![explosions](screenshots/exploooosiiiiiooons.jpg "Exploooosiiiiiooons")
![gameover](screenshots/gameover.png "Game Over")
