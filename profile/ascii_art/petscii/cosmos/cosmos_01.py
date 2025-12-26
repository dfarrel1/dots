import curses
import math
import random

def main(stdscr):
    # Setup
    curses.curs_set(0) # Hide cursor
    stdscr.nodelay(1)  # Non-blocking input
    stdscr.timeout(100) # Refresh rate
    
    # Colors: White stars, Yellow core, maybe Blue arms if terminal supports
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_WHITE, -1)
        curses.init_pair(2, curses.COLOR_YELLOW, -1)
        curses.init_pair(3, curses.COLOR_CYAN, -1)
        curses.init_pair(4, curses.COLOR_MAGENTA, -1)

    h, w = stdscr.getmaxyx()
    cx, cy = w // 2, h // 2
    
    # Galaxy Parameters
    num_arms = 2
    arm_separation = 0.5  # How tight the spiral is
    max_radius = min(cx, cy) - 2
    num_stars = 2000      # Increase for more density
    
    # PETSCII-ish Character Palette (Dark -> Light)
    # Using block elements and distinct symbols to mimic the C64/MEGA65 look
    palette = [".", ",", "`", "'", ":", ";", "*", "+", "o", "O", "&", "%", "@", "#"]

    # Pre-calculate star positions
    stars = []
    
    # 1. Generate The Core (Dense Blob)
    for _ in range(300):
        angle = random.uniform(0, 2 * math.pi)
        dist = random.triangular(0, max_radius * 0.15, 0) # Bias toward center
        stars.append((dist, angle, 2)) # Color 2 (Yellow)

    # 2. Generate Spiral Arms
    for i in range(num_stars):
        # Pick an arm
        arm_offset = (random.randint(0, num_arms - 1) / num_arms) * 2 * math.pi
        
        # Distance from center (randomized)
        dist = random.uniform(0.1, max_radius)
        
        # Logarithmic Spiral Formula: angle grows with distance
        # "swirl_factor" determines how much it winds. Higher = more wind.
        swirl_factor = 4.0 
        base_angle = (math.log(dist + 1) * swirl_factor) + arm_offset
        
        # Add "Fuzz" (random scatter off the perfect line)
        # The further out, the more scatter
        fuzz = random.gauss(0, 0.5 + (dist / max_radius))
        final_angle = base_angle + fuzz
        
        # Color Logic: Inner = Yellow, Mids = White, Outer = Cyan/Magenta
        col = 1
        if dist < max_radius * 0.2: col = 2
        elif dist > max_radius * 0.7: col = random.choice([3, 4])

        stars.append((dist, final_angle, col))

    # Animation Loop (Draws progressively like the BASIC demo)
    draw_batch = 50 # How many stars to draw per frame
    current_star = 0
    
    while True:
        # Check for ANY keypress to exit immediately
        ch = stdscr.getch()
        if ch != -1: 
            break

        # Draw a batch of stars
        if current_star < len(stars):
            for _ in range(draw_batch):
                if current_star >= len(stars): break
                
                dist, angle, col = stars[current_star]
                
                # Polar to Cartesian
                x = cx + int(dist * math.cos(angle) * 2) # *2 for aspect ratio correction
                y = cy + int(dist * math.sin(angle))
                
                if 0 <= x < w and 0 <= y < h:
                    # Pick a character based on "Density" or Randomness
                    # In true procedural art, we might check overlapping, but random works here
                    char = random.choice(palette)
                    
                    try:
                        # Make center brighter/bolder
                        attr = curses.A_NORMAL
                        if dist < max_radius * 0.2: attr = curses.A_BOLD
                        
                        stdscr.addch(y, x, char, curses.color_pair(col) | attr)
                    except curses.error:
                        pass # Ignore edge rendering errors
                
                current_star += 1
            
            stdscr.refresh()
        else:
            # Once done drawing, just wait (low CPU usage)
            time.sleep(0.1)

if __name__ == "__main__":
    import time
    curses.wrapper(main)
