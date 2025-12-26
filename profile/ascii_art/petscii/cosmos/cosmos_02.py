import curses
import math
import random

def main(stdscr):
    # --- Configuration ---
    # Attempt to match the "BBC Basic Mode 1" palette described in the demo
    # The original uses high-contrast reds/yellows against black.
    
    curses.curs_set(0) # Hide cursor
    stdscr.nodelay(1)  # Non-blocking input
    
    # Initialize Colors
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        # Pair 1: Bright White (Core)
        curses.init_pair(1, curses.COLOR_WHITE, -1) 
        # Pair 2: Yellow (Inner Arms)
        curses.init_pair(2, curses.COLOR_YELLOW, -1)
        # Pair 3: Red (Outer Arms)
        curses.init_pair(3, curses.COLOR_RED, -1)
        # Pair 4: Dim Red/Magenta (Fading edges)
        curses.init_pair(4, curses.COLOR_MAGENTA, -1)

    # Screen Dimensions
    h, w = stdscr.getmaxyx()
    cx, cy = w // 2, h // 2
    
    # --- The "p_malin" Algorithm Adaptation ---
    # The original BASIC program draws ~30 lines of code.
    # It typically uses a "Inverse Square" density for the core and 
    # Logarithmic Spirals for the arms.
    
    particles = []
    
    # We need a LOT of points to match that dense screenshot
    num_particles = 10000 
    
    # Scale factors to fit the terminal
    # The image is tilted, so Y is compressed (approx 0.4 aspect ratio)
    scale_x = w / 3.5
    scale_y = h / 2.5 * 0.5 # The 0.5 creates the "Tilt" effect
    
    chars = ".,`'::;*+oO&%#@" # Density characters

    for i in range(num_particles):
        # 1. Random distributions
        # We use a power function to bias points toward the center (Bulge)
        # random.random() ** 2.0 pushes values closer to 0
        r_base = random.random() ** 1.5 
        
        # 2. Define the Arms (2 Arms)
        # We pick either arm 0 (0 radians) or arm 1 (PI radians)
        arm_offset = math.pi if random.random() > 0.5 else 0
        
        # 3. Logarithmic Spiral Equation
        # The angle increases as the radius increases (winding the arm)
        # 'wind_factor' determines how tight the spiral is.
        wind_factor = 5.0
        spiral_angle = (r_base * wind_factor) + arm_offset
        
        # 4. Add "Scatter" (The dusty look)
        # Points aren't perfectly on the line; they scatter more as they go out.
        scatter = random.gauss(0, 0.2 + (r_base * 0.5))
        final_angle = spiral_angle + scatter
        
        # 5. Polar -> Cartesian Conversion
        x = cx + (math.cos(final_angle) * r_base * scale_x)
        y = cy + (math.sin(final_angle) * r_base * scale_y)
        
        # 6. Color & Character Logic based on Radius (r_base)
        # Core (0.0 - 0.15): White, Dense
        # Inner (0.15 - 0.4): Yellow, Medium
        # Outer (0.4 - 1.0): Red, Sparse
        
        col = 1
        char = '.'
        
        if r_base < 0.15:
            col = 1 # White
            char = random.choice("O@#") # Dense core
        elif r_base < 0.4:
            col = 2 # Yellow
            char = random.choice("*o+") 
        elif r_base < 0.7:
            col = 3 # Red
            char = random.choice(":;.")
        else:
            col = 4 # Dim
            char = "."

        # Store particle
        if 0 <= int(y) < h and 0 <= int(x) < w:
            particles.append((int(y), int(x), char, col))

    # --- Rendering ---
    # We draw simply. No loop needed for animation, just static render + wait.
    
    # Sort particles? 
    # In a 2D terminal, later draws overwrite earlier ones. 
    # Drawing the "Core" LAST ensures it stays bright white on top of the arms.
    particles.sort(key=lambda p: p[3], reverse=True) # Draw Red first, White last
    
    for p in particles:
        try:
            # y, x, char, color_pair_index
            stdscr.addch(p[0], p[1], p[2], curses.color_pair(p[3]))
        except curses.error:
            pass # Ignore edge cases

    stdscr.refresh()
    
    # --- Input Loop ---
    # Wait for a keypress to exit
    while True:
        key = stdscr.getch()
        if key != -1:
            break
        curses.napms(50)

if __name__ == "__main__":
    curses.wrapper(main)