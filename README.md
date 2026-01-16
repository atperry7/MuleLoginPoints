# Mule Login Points

A Windower addon for Final Fantasy XI that automatically logs into multiple mules to collect their daily login point bonuses.

## Installation

1. Make sure this folder is in your Windower addons directory:

   ```
   Windower4/addons/MuleLoginPoints/
   ```

2. Load the addon in-game by typing:

   ```
   //lua l MuleLoginPoints
   ```

3. Press "INSERT" to open Windower Console, then type

   ```
   lua l MuleLoginPoints
   ```

4. (Optional) Add it to your startup by editing `Windower4/scripts/init.txt` and adding:

   ```
   lua l MuleLoginPoints
   ```

## How to Use

**Goal:** Automatically login to all your mule characters to collect their daily login point bonuses, then logout and move to the next character.

### Step 1: Configure Your Character Slots

First, you need to tell the addon which character slots to login. Character slots are numbered 1-16 on your character select screen.

**Example:** If your mules are in slots 2, 3, 4, 5, and 10, type:
```
//mls slots 2 3 4 5 10
```

The addon will remember this configuration and use it every time.

To see which slots are currently configured:
```
//mls slots
```

### Step 2: Start at Character Select

- **IMPORTANT:** You must be at the character select screen before starting the addon.
- **IMPORTANT:** *Default Timings* assume every character is in the Mog House for best results.
- **IMPORTANT:** *Default Settings* assume you are not using the Logout Desination -> Select Character

If you're currently logged in:
1. Type `/logout` to logout
2. Navigate until you reach the character select screen

#### FFXI Config Option: Logout Destination -> Select Character

This is not enabled by default when you install FFXI.

By default, when a character logs out, the game shows the main menu before returning to character select. If you have the "Logout Destination -> Select Character" option enabled in your "Main Menu" FFXI Config, you can enable this setting for faster cycling:

To enable in the addon, edit your settings file and set:

```xml
<config_logout_destination_select_character>true</config_logout_destination_select_character>
```

**Benefits:**
- Skips the main menu navigation (saves time)
- More efficient slot navigation (cursor stays at current slot instead of resetting to slot 1)
- Fewer key presses overall

**Note:** Only enable this if you have the corresponding option enabled in your FFXI settings, otherwise the addon may get stuck.

### Step 3: Start the Cycle

Once you're at the character select screen:
```
Press "INSERT" to open Windower Console
Type: mls start
```

The addon will now:
- Navigate to each configured character slot
- Login to the character
- Wait for the daily login point bonus to be awarded (15 seconds by default)
- Logout automatically
- Move to the next character
- Repeat until all characters have collected their daily login points

### Step 4: Wait for Completion

The addon will tell you its progress in the chat log. You'll see messages like:
- "Processing slot 2 (1/5)"
- "Login detected - character loaded"
- "SUCCESS: Logged into [Character Name] from target slot 2"

When finished, you'll see:
```
Mule login cycle complete! At character select - pick your character.
```

The addon will automatically unload itself when done.

## Commands Reference

| Command | What It Does |
|---------|-------------|
| `//mls start` | Starts the automatic login cycle |
| `//mls stop` | Stops the cycle if something goes wrong |
| `//mls status` | Shows what the addon is currently doing |
| `//mls slots` | Shows which character slots are configured |
| `//mls slots 2 3 4 5` | Sets which character slots to login (in order) |
| `//mls delay` | Shows timing settings (advanced) |
| `//mls help` | Shows the list of commands |

## Login Logs

Every time a character logs in, the addon creates a log file in:
```
Windower4/addons/MuleLoginPoints/logs/
```

The log file is named by date (e.g., `2026-01-14_login_log.txt`) and contains:
```
[14:32:15] Slot 2: CharacterName
[14:32:45] Slot 3: AnotherCharacter
[14:33:12] Slot 4: ThirdCharacter
```

This helps you verify which characters were processed and when.

## Troubleshooting

### "Already logged in! Please logout first"
You need to be at the character select screen. Type `/logout` and wait until you see the character list.

### "Cycle already in progress!"
The addon is already running. Wait for it to finish, or type `//mls stop` to abort.

### The addon got stuck or selected the wrong character
Type `//mls stop` to abort the cycle. You may need to adjust the timing delays (see Advanced Settings below).

### A character didn't login properly
Check the log files in the `logs/` folder to see which characters were successfully processed. You can manually login any that were missed.

## Advanced Settings

### Timing Delays

If the addon is going too fast or too slow for your connection, you can adjust the delays:

View current delays:
```
//mls delay
```

Change a specific delay (time in seconds):
```
//mls delay wait_for_login 20
```

Available delay settings:
- `key_press` - How long to hold down arrow keys (default: 0.1s)
- `key_between` - Wait time between key presses (default: 1.0s)
- `wait_for_login` - Wait after selecting character (default: 15s)
- `wait_for_logout` - Wait after logout command (default: 5s)
- `wait_for_menu` - Wait at main menu (default: 5s)
- `wait_for_charselect` - Wait at character select (default: 5s)

If you have a slow connection, try increasing `wait_for_login` to 20 or 25 seconds.

## Configuration File

Settings are saved automatically in:
```
Windower4/addons/MuleLoginPoints/data/settings.xml
```

You can edit this file directly if needed, but it's easier to use the `//mls slots` and `//mls delay` commands.
