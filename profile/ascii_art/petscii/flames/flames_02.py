import curses, random, time

def main(stdscr):
    # Setup standard screen
    curses.curs_set(0)
    stdscr.nodelay(1)  # Make getch non-blocking
    stdscr.timeout(50) # Refresh every 50ms
    
    # Colors: Define a gradient from white -> yellow -> red -> black
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        for i in range(1, 8):
            curses.init_pair(i, i, -1) # Simple ANSI colors mapping

    h, w = stdscr.getmaxyx()
    fire_h = h  # Height of fire simulation
    fire_w = w  # Width of fire
    fire = [0] * (fire_w * fire_h)
    
    # Characters mapping density to ASCII (PETSCII-ish look)
    chars = " ...::/\\|%#@"
    
    while True:
        # Check for ANY keypress to exit immediately
        ch = stdscr.getch()
        if ch != -1: 
            break

        # Fire Algorithm (Doom Fire)
        for x in range(fire_w):
            fire[int((fire_h - 1) * fire_w + x)] = random.randint(0, 32767) % len(chars) * 2

        for y in range(fire_h - 1):
            for x in range(fire_w):
                src = int((y + 1) * fire_w + x)
                val = fire[src] - random.randint(0, 1)
                fire[int(y * fire_w + x)] = max(val, 0)

        # Draw
        for y in range(fire_h - 1):
            for x in range(fire_w):
                val = fire[y * fire_w + x]
                char_idx = min(len(chars) - 1, val)
                
                # Simple color mapping based on intensity
                color = 0
                if char_idx > 8: color = 1  # Red/White
                elif char_idx > 4: color = 3 # Yellow
                elif char_idx > 0: color = 4 # Blue/Dim
                
                try:
                    stdscr.addch(y, x, chars[char_idx], curses.color_pair(color) | curses.A_BOLD)
                except curses.error:
                    pass
        
        stdscr.refresh()

if __name__ == "__main__":
    curses.wrapper(main)