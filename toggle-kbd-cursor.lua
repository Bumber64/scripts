local guidm = require('gui.dwarfmode')

if dfhack.world.isAdventureMode() then
    qerror('Adventure mode unsupported!')
end

local flags = df.global.d_init.feature.flags
if flags.KEYBOARD_CURSOR then
    flags.KEYBOARD_CURSOR = false
    guidm.clearCursorPos()
    print('Keyboard cursor disabled.')
else
    guidm.setCursorPos(guidm.Viewport.get():getCenter())
    flags.KEYBOARD_CURSOR = true
    print('Keyboard cursor enabled.')
end
