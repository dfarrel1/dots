### Step-by-Step Guide to Fix External Monitor Resolution Issue on macOS

**Objective:** Set the external monitor resolution and refresh rate correctly when the laptop lid is closed.

#### Prerequisites:
- Homebrew installed on your Mac.
- The `screenresolution` tool installed via Homebrew.

#### Steps:

1. **Install `screenresolution` with Homebrew:**
   ```sh
   brew install screenresolution
   ```

2. **Identify Possible Screen Resolutions:**
   - With the laptop open, connect the external monitor and list the available resolutions:
     ```sh
     screenresolution list
     ```
   - Note that the list of resolutions might not be accurate for the closed-lid scenario.

3. **Diagnose Resolutions with Laptop Closed:**
   - Close the laptop lid and let the external monitor engage. If it shows a resolution mismatch complaint, you will need to set a compatible resolution blindly:
     ```sh
     screenresolution list
     ```
   - Record the available resolutions even if you can’t see them on the monitor.

4. **Prepare to Set the Resolution:**
   - Open the laptop lid for visibility.
   - Select a suitable resolution and prepare the command to set it:
     ```sh
     screenresolution set <width>x<height>x<depth>@<refresh_rate>
     ```
   - Replace `<width>`, `<height>`, `<depth>`, and `<refresh_rate>` with appropriate values from your recorded list.

5. **Set Resolution with Laptop Closed:**
   - Close the laptop lid again.
   - Wait for the external monitor to engage (it might still show a resolution mismatch).
   - Run the prepared command to set the resolution:
     ```sh
     screenresolution set <width>x<height>x<depth>@<refresh_rate>
     ```

6. **Verify and Adjust Resolution in System Settings:**
   - The external monitor should now be visible with the laptop closed.
   - Open **System Settings** > **Displays**.
   - Use the graphical interface to select the highest available resolution and refresh rate.

7. **Final Verification:**
   - Ensure that the external monitor works as expected with the laptop lid closed and the resolution settings are retained.

#### Summary:
By following these steps, you can set the external monitor's resolution and refresh rate correctly when the laptop lid is closed. This ensures that the monitor displays properly, even if it requires some initial configuration via the command line and graphical interface.