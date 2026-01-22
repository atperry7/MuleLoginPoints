--Copyright (c) 2026, atperry7
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of Mule Login Points nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL Chiaia BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

_addon.name = 'Mule Login Points'
_addon.version = '1.1.0'
_addon.author = 'atperry7'
_addon.commands = {'mulelogin', 'mls'}

require('logger')
config = require('config')

-- State constants
local STATE = {
    IDLE = 'idle',
    NAVIGATING = 'navigating',
    LOGGING_IN = 'logging_in',
    IN_GAME = 'in_game',
    LOGGING_OUT = 'logging_out',
    AT_MAIN_MENU = 'at_main_menu',
    AT_CHAR_SELECT = 'at_char_select',
    COMPLETE = 'complete',
}

-- Default configuration
local defaults = {
    slots = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16},  -- Slots to login in order
    delays = {
        key_press = 0.1,  -- Duration to hold key down
        key_between = 0.5,  -- Wait between key presses - increased for reliability
        wait_for_login = 10,
        wait_for_logout = 5,
        wait_for_menu = 5,
        wait_for_charselect = 5,
    },
    config_logout_destination_select_character = false
}

local settings = config.load(defaults)

-- State tracking
local state = {
    current = STATE.IDLE,
    slot_queue = {},
    current_slot = 1,
    target_slot = nil,
    mule_index = 0,
    running = false,
}

-- Helper: Press a key (down, hold, up)
local function press_key(key)
    windower.send_command('setkey ' .. key .. ' down')
    coroutine.sleep(settings.delays.key_press)
    windower.send_command('setkey ' .. key .. ' up')
    coroutine.sleep(settings.delays.key_between)
end

-- Navigation: Calculate steps from one slot to another
-- Character select is a vertical list: slots 1-16 accessed by down/up arrows
-- Slot 1 = 0 moves, Slot 2 = 1 down, Slot 5 = 4 down, etc.
local function get_navigation_steps(from_slot, to_slot)
    local steps = {}
    local slot_diff = to_slot - from_slot

    if slot_diff > 0 then
        -- Move down
        for i = 1, slot_diff do
            table.insert(steps, 'down')
        end
    elseif slot_diff < 0 then
        -- Move up
        for i = 1, -slot_diff do
            table.insert(steps, 'up')
        end
    end
    -- If slot_diff == 0, no movement needed

    return steps
end

-- Navigate to a target slot
local function navigate_to_slot(target_slot)
    state.current = STATE.NAVIGATING
    state.target_slot = target_slot

    -- Calculate navigation from current cursor position
    local steps = get_navigation_steps(state.current_slot, target_slot)

    if #steps > 0 then
        log('Navigating from slot ' .. state.current_slot .. ' to slot ' .. target_slot .. ' (' .. #steps .. ' key presses)')

        -- Extra safety delay before starting navigation
        coroutine.sleep(1)

        for i, direction in ipairs(steps) do
            log('  Step ' .. i .. '/' .. #steps .. ': pressing ' .. direction)
            press_key(direction)
        end

        log('Navigation complete - should be at slot ' .. target_slot)
    else
        log('Already at slot ' .. target_slot .. ' - no navigation needed')
    end

    state.current_slot = target_slot
end

-- Login the current character
local function login_character()
    state.current = STATE.LOGGING_IN

    log('Selecting character in slot ' .. state.target_slot)
    press_key('enter')  -- Select the character

    log('Confirming character selection')
    press_key('enter')  -- Confirm the selection
end

-- Forward declarations
local process_next_slot
local handle_character_select

-- Handle being at character select screen
-- Note: When using direct-to-char-select, cursor stays at current slot (more efficient)
-- When coming from main menu, cursor resets to slot 1
handle_character_select = function(cursor_was_reset)
    state.current = STATE.AT_CHAR_SELECT

    log('At character select screen')
    coroutine.sleep(settings.delays.wait_for_charselect)

    -- If cursor was reset (came from main menu), update our tracking
    if cursor_was_reset then
        state.current_slot = 1
    end

    -- Check if we've completed all characters
    if state.mule_index >= #state.slot_queue then
        state.current = STATE.COMPLETE
        state.running = false
        log('Mule login cycle complete! At character select - pick your character.')
        log('Unloading addon...')
        windower.send_command('lua u muleloginpoints')
        return
    end

    -- Continue to next character
    process_next_slot()
end

-- Handle main menu after logout
local function handle_main_menu()
    state.current = STATE.AT_MAIN_MENU

    log('At main menu, pressing Enter to continue...')
    coroutine.sleep(settings.delays.wait_for_menu)

    -- Press Enter Key once since we are past the Accept Terms
    press_key('enter')

    -- Now at character select screen (cursor will reset to slot 1)
    handle_character_select(true)
end

-- Logout current character
local function logout_character()
    state.current = STATE.LOGGING_OUT

    log('Sending /logout command')
    windower.send_command('input /logout')

    coroutine.sleep(settings.delays.wait_for_logout)

    -- Check if we're configured to go directly to character select
    -- Note: Direct-to-char-select keeps cursor at current slot (more efficient navigation)
    --       Main menu path resets cursor to slot 1 (requires full navigation each time)
    if settings.config_logout_destination_select_character then
        log('Logout destination: Character select (skipping main menu)')
        -- Cursor stays at state.current_slot, no reset
        handle_character_select(false)
    else
        log('Logout destination: Main menu')
        -- Cursor will reset to slot 1
        handle_main_menu()
    end
end

-- Process the next slot in queue
process_next_slot = function()
    if not state.running then
        return
    end

    state.mule_index = state.mule_index + 1

    if state.mule_index > #state.slot_queue then
        state.current = STATE.COMPLETE
        state.running = false
        log('Mule login cycle complete!')
        return
    end

    local next_slot = state.slot_queue[state.mule_index]
    log('Processing slot ' .. next_slot .. ' (' .. state.mule_index .. '/' .. #state.slot_queue .. ')')

    navigate_to_slot(next_slot)
    login_character()
end

-- Start the mule cycle
local function start_cycle()
    if state.running then
        error('Cycle already in progress! Use //mls stop to abort.')
        return
    end

    if #settings.slots < 1 then
        error('No slots configured! Use //mls slots 1 3 5 16 to set slots.')
        return
    end

    local info = windower.ffxi.get_info()
    if info and info.logged_in then
        error('Already logged in! Please logout first and start from character select.')
        print('MLS Error: Already logged in! Please logout first and start from character select.')
        return
    end

    -- Build queue: simply copy all configured slots in order
    state.slot_queue = {}

    for i = 1, #settings.slots do
        table.insert(state.slot_queue, settings.slots[i])
    end

    if #state.slot_queue == 0 then
        error('No slots configured! Use //mls slots 2 3 4 5 to set slots.')
        return
    end

    state.mule_index = 0
    state.current_slot = 1
    state.running = true

    log('Starting mule login cycle with ' .. #state.slot_queue .. ' character(s)')
    log('Order: ' .. table.concat(state.slot_queue, ' -> '))

    process_next_slot()
end

-- Stop/abort the cycle
local function stop_cycle()
    if not state.running then
        notice('No cycle in progress')
        return
    end

    log('Aborting mule login cycle')
    state.current = STATE.IDLE
    state.slot_queue = {}
    state.mule_index = 0
    state.running = false
end

-- Log successful character login to daily file
local function log_character_login(char_name, slot)
    local date = os.date('%Y-%m-%d')
    local timestamp = os.date('%H:%M:%S')
    local log_dir = windower.addon_path .. 'logs'
    local log_file = log_dir .. '\\' .. date .. '_login_log.txt'

    -- Create logs directory if it doesn't exist
    windower.create_dir(log_dir)

    -- Append to daily log file
    local file = io.open(log_file, 'a')
    if file then
        file:write(string.format('[%s] Slot %d: %s\n', timestamp, slot, char_name))
        file:close()
        log('Logged character "' .. char_name .. '" to: ' .. date .. '_login_log.txt')
    else
        error('Failed to write to log file: ' .. log_file)
    end
end

-- Event: Character logged in
windower.register_event('login', function()
    -- Only process login if we're actively running the cycle and expecting a login
    if not state.running then
        return
    end

    if state.current ~= STATE.LOGGING_IN then
        log('WARNING: Unexpected login detected while in state: ' .. state.current)
        return
    end

    if not state.target_slot then
        log('ERROR: Login detected but no target slot set!')
        return
    end

    log('Login detected - character loaded')
    state.current = STATE.IN_GAME

    -- Get character name and log to file
    local player = windower.ffxi.get_player()
    if player and player.name then
        log('SUCCESS: Logged into "' .. player.name .. '" from target slot ' .. state.target_slot)
        log_character_login(player.name, state.target_slot)
    else
        log('WARNING: Could not retrieve character name')
    end

    -- Always logout to continue cycling through characters
    coroutine.sleep(settings.delays.wait_for_login)
    logout_character()
end)

-- Event: Character logged out
windower.register_event('logout', function()
    if state.current == STATE.LOGGING_OUT and state.running then
        log('Logout detected')
    end
end)

-- Event: Addon commands
windower.register_event('addon command', function(command, ...)
    command = command and command:lower() or 'help'
    local args = {...}

    if command == 'start' then
        start_cycle()

    elseif command == 'stop' or command == 'abort' then
        stop_cycle()

    elseif command == 'status' then
        local dest = settings.config_logout_destination_select_character and 'Character Select' or 'Main Menu'
        log('State: ' .. state.current)
        log('Running: ' .. tostring(state.running))
        if state.running then
            log('Progress: ' .. state.mule_index .. '/' .. #state.slot_queue)
        end
        log('Configured slots: ' .. table.concat(settings.slots, ', '))
        log('Logout destination: ' .. dest)
        -- Also print to console (works at character select)
        print('MLS State: ' .. state.current)
        print('MLS Running: ' .. tostring(state.running))
        if state.running then
            print('MLS Progress: ' .. state.mule_index .. '/' .. #state.slot_queue)
        end
        print('MLS Configured slots: ' .. table.concat(settings.slots, ', '))
        print('MLS Logout destination: ' .. dest)

    elseif command == 'slots' then
        if #args > 0 then
            local new_slots = {}
            for _, arg in ipairs(args) do
                local num = tonumber(arg)
                if num and num >= 1 and num <= 16 then
                    table.insert(new_slots, num)
                else
                    error('Invalid slot: ' .. arg .. ' (must be 1-16)')
                    print('MLS Error: Invalid slot: ' .. arg .. ' (must be 1-16)')
                    return
                end
            end
            if #new_slots > 0 then
                settings.slots = new_slots
                settings:save()
                log('Slots updated: ' .. table.concat(new_slots, ', '))
                log('Will login ' .. #new_slots .. ' character(s) in order')
                print('MLS Slots updated: ' .. table.concat(new_slots, ', '))
                print('MLS Will login ' .. #new_slots .. ' character(s) in order')
            end
        else
            log('Current slots: ' .. table.concat(settings.slots, ', '))
            log('Will login ' .. #settings.slots .. ' character(s) in order')
            print('MLS Current slots: ' .. table.concat(settings.slots, ', '))
            print('MLS Will login ' .. #settings.slots .. ' character(s) in order')
        end

    elseif command == 'delay' then
        if args[1] and args[2] then
            local key = args[1]
            local value = tonumber(args[2])
            if settings.delays[key] and value then
                settings.delays[key] = value
                settings:save()
                log('Delay ' .. key .. ' set to ' .. value .. 's')
            else
                error('Invalid delay key or value')
            end
        else
            log('Current delays:')
            for k, v in pairs(settings.delays) do
                log('  ' .. k .. ': ' .. v .. 's')
            end
        end

    elseif command == 'logoutdest' then
        if args[1] then
            local dest = args[1]:lower()
            if dest == 'charselect' or dest == 'char' then
                settings.config_logout_destination_select_character = true
                settings:save()
                log('Logout destination set to: Character Select (direct)')
                print('MLS Logout destination set to: Character Select (direct)')
            elseif dest == 'mainmenu' or dest == 'menu' then
                settings.config_logout_destination_select_character = false
                settings:save()
                log('Logout destination set to: Main Menu')
                print('MLS Logout destination set to: Main Menu')
            else
                error('Invalid option. Use: charselect or mainmenu')
                print('MLS Error: Invalid option. Use: charselect or mainmenu')
            end
        else
            local current = settings.config_logout_destination_select_character and 'Character Select' or 'Main Menu'
            log('Current logout destination: ' .. current)
            log('Usage: //mls logoutdest charselect  OR  //mls logoutdest mainmenu')
            print('MLS Current logout destination: ' .. current)
            print('MLS Usage: //mls logoutdest charselect  OR  //mls logoutdest mainmenu')
        end

    else -- help
        log('Mule Login Point Switcher v' .. _addon.version)
        log('Commands:')
        log('  //mls start           - Start the mule login cycle')
        log('  //mls stop            - Abort the current cycle')
        log('  //mls status          - Show current state')
        log('  //mls slots           - View configured slots')
        log('  //mls slots 2 3 5 16  - Set slots to login in order')
        log('  //mls logoutdest      - View/set logout destination (charselect or mainmenu)')
        log('  //mls delay           - View timing delays')
        log('  //mls delay <key> <s> - Set a delay value')
        log('  //mls help            - Show this help')
        -- Also print to console (works at character select)
        print('Mule Login Point Switcher v' .. _addon.version)
        print('Commands:')
        print('  //mls start           - Start the mule login cycle')
        print('  //mls stop            - Abort the current cycle')
        print('  //mls status          - Show current state')
        print('  //mls slots           - View configured slots')
        print('  //mls slots 2 3 5 16  - Set slots to login in order')
        print('  //mls logoutdest      - View/set logout destination (charselect or mainmenu)')
        print('  //mls delay           - View timing delays')
        print('  //mls delay <key> <s> - Set a delay value')
        print('  //mls help            - Show this help')
    end
end)

log('Mule Login Point Switcher loaded. Type //mls help for commands.')
print('Mule Login Point Switcher loaded. Type //mls help for commands.')
