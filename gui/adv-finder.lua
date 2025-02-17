-- Find and track historical figures --TODO: and artifacts

local gui = require('gui')
local widgets = require('gui.widgets')

local world = df.global.world
local transName = dfhack.translation.translateName

local LType = {None = 0, Local = 1, Wild = 2, Under = 3, Site = 4, Army = 5} --Location type

-- Fns for getting adventurer data --

local function region_from_travel(t_pos) --Convert to region coords
    return t_pos and {x = t_pos.x//48, y = t_pos.y//48} or nil
end

local function travel_from_local(pos) --Calc travel coord from map pos
    return pos and {x = world.map.region_x*3 + pos.x//16, y = world.map.region_y*3 + pos.y//16} or nil
end

local function get_adv_data() --All the coords we can get
    local adv = dfhack.world.getAdventurer()
    if not adv then --Army exists when unit doesn't
        local army = df.army.find(df.global.adventure.player_army_id)
        if army then --Should always exist if unit doesn't
            return {r_pos = region_from_travel(army.pos), t_pos = army.pos}
        end
        return nil --Error
    end
    local mmd = world.world_data.midmap_data
    return {r_pos = {x = mmd.adv_region_x, y = mmd.adv_region_y}, t_pos = travel_from_local(adv.pos), pos = adv.pos}
end

-- Fns for getting target data --

local function get_hf_data(hf) --Whereabouts data and coords
    if not hf then --No target
        return nil
    end
    local where = hf.info and hf.info.whereabouts
    if not where then --Deity or no data (worldgen death?)
        return {loc_type = LType.None}
    end

    local unit = df.unit.find(hf.unit_id)
    if unit then --Unit is nearby
        local t_pos = travel_from_local(unit.pos)
        return {loc_type = LType.Local, r_pos = region_from_travel(t_pos), t_pos = t_pos, pos = unit.pos}
    end

    local t_pos = where.abs_smm_x ~= -1 and {x = where.abs_smm_x, y = where.abs_smm_y} or nil
    if where.subregion_id ~= -1 then --Surface region
        if t_pos then
            t_pos.z = 0 --Must be surface
        end
        return {loc_type = LType.Wild, r_pos = region_from_travel(t_pos), t_pos = t_pos}
    end

    if where.feature_layer_id ~= -1 then --Cavern layer
        if t_pos then
            local layer = df.world_underground_region.find(where.feature_layer_id)
            t_pos.z = layer and layer.layer_depth or nil
        end
        return {loc_type = LType.Under, r_pos = region_from_travel(t_pos), t_pos = t_pos}
    end

    if where.site_id ~= -1 then --Site
        local site = df.world_site.find(where.site_id)
        if site then
            if t_pos then
                t_pos.z = site.min_depth == site.max_depth and site.min_depth or nil
            end
            return {loc_type = LType.Site, site = site, r_pos = region_from_travel(t_pos), t_pos = t_pos}
        end
    end

    local army = df.army.find(where.army_id)
    if army then
        return {loc_type = LType.Army, r_pos = region_from_travel(army.pos), t_pos = army.pos}
    end
    return nil --Unhandled, insufficient data
end

-- Fns for names and searching --

local function get_race_name(hf)
    return dfhack.capitalizeStringWords(dfhack.units.getRaceReadableNameById(hf.race))
end

local function get_full_name(hf) --'Native Name "Translated Name", Race'
    local full_name = transName(hf.name, false)
    if full_name == '' then --Improve searchability
        full_name = 'Anonymous'
    else --Add the translation
        full_name = full_name..' "'..transName(hf.name, true)..'"'
    end
    local race_name = get_race_name(hf)
    if race_name == '' then --Elf deities don't have a race
        full_name = full_name..', Force'
    else --Add the race
        full_name = full_name..', '..race_name
    end
    return full_name
end

local function search_str(s) --Return searchable string
    return dfhack.upperCp437(dfhack.toSearchNormalized(s))
end

local function match_name(search_name, hf) --Return name string if partial match
    local hf_name = get_full_name(hf)
    if string.match(search_str(hf_name), search_name) then
        return hf_name
    end
end

local function search_hf(search_name) --Return all matching HFs. (Use search_str first!)
    local found = {}
    for _,hf in ipairs(world.history.figures) do
        local name = match_name(search_name, hf)
        if name then
            if hf.died_year ~= -1 then
                name = {{text=name, pen=COLOR_RED}} --Dead
            elseif not hf.info or not hf.info.whereabouts then
                name = {{text=name, pen=COLOR_YELLOW}} --Deity (usually)
            end
            table.insert(found, {name, hf})
        end
    end
    return found
end

AdvFindWindow = defclass(AdvFindWindow, widgets.Window)
AdvFindWindow.ATTRS{
    frame = {w=75, h=26, t=18, r=2},
    resizable = true,
    frame_title = 'Finder',
}

function AdvFindWindow:init()
    self:addviews{
        widgets.Label{
            view_id = 'search_label',
            text = {{text='Search: ', pen=COLOR_LIGHTGREEN}},
            frame = {t=0, l=0},
        },
        widgets.List{
            view_id = 'sel_list',
            frame = {t=2, l=0, w=40},
            on_submit = self:callback('on_submit_choice'),
        },
        widgets.Label{
            view_id = 'found_label',
            text = '',
            frame = {t=2, l=0},
        },
        widgets.EditField{
            view_id = 'search_field',
            frame = {t=0, l=8},
            on_submit = self:callback('on_edit_change'),
        },
        widgets.Panel{
            view_id = 'adv_panel',
            frame = {t=1, r=0, w=30, h=10},
            frame_style = gui.FRAME_INTERIOR,
            subviews = {
                widgets.Label{
                    view_id = 'adv_label',
                    text = '',
                    frame = {t=0, l=0},
                },
            },
        },
        widgets.Panel{
            view_id = 'hf_panel',
            frame = {t=13, r=0, w=30, h=10},
            frame_style = gui.FRAME_INTERIOR,
            subviews = {
                widgets.Label{
                    view_id = 'hf_label',
                    text = '',
                    frame = {t=0, l=0},
                },
            },
        },
    }
end

-- Fns for adventurer info panel --

local compass_dir = {
    'E','ENE','NE','NNE',
    'N','NNW','NW','WNW',
    'W','WSW','SW','SSW',
    'S','SSE','SE','ESE',
}
local compass_pointer = { --Same chars as movement indicators
    '>',string.char(191),string.char(191),string.char(191),
    '^',string.char(218),string.char(218),string.char(218),
    '<',string.char(192),string.char(192),string.char(192),
    'v',string.char(217),string.char(217),string.char(217),
}

local idx_div_two_pi = 16/(2*math.pi) --16 indices / 2*Pi radians
local function compass(dx, dy) --Handy compass string
    if dx*dx + dy*dy == 0 then --On target
      return string.char(249)..' ***' --Char 249 is centered dot
    end
    local angle = math.atan(-dy, dx) --North is -Y
    local index = math.floor(angle*idx_div_two_pi + 16.5)%16 --0.5 helps rounding
    return compass_pointer[index + 1]..' '..compass_dir[index + 1]
end

local function insert_txt(t, txt) --Insert newline before txt
    if txt and txt ~= '' then
        table.insert(t, NEWLINE)
        table.insert(t, txt)
    end
end

local function relative_txt(adv_data, hf_data) --Relative coords and compass
    local txt = {}
    if not hf_data then --Different worlds
        return txt
    end
    if hf_data.pos and adv_data.pos then --Use local
        local dx = hf_data.pos.x - adv_data.pos.x
        local dy = hf_data.pos.y - adv_data.pos.y
        table.insert(txt, NEWLINE)
        insert_txt(txt, 'target (local):')
        insert_txt(txt, compass(dx, dy))
        insert_txt(txt, ('X%+d Y%+d Z%+d'):format(dx, dy, hf_data.pos.z - adv_data.pos.z))
    elseif hf_data.t_pos and adv_data.t_pos then --Use travel
        local dx = hf_data.t_pos.x - adv_data.t_pos.x
        local dy = hf_data.t_pos.y - adv_data.t_pos.y
        table.insert(txt, NEWLINE)
        insert_txt(txt, 'target (travel):')
        insert_txt(txt, compass(dx, dy))

        local s = ('X%+d Y%+d'):format(dx, dy)
        if hf_data.t_pos.z and adv_data.t_pos.z then --Use Z if we have it
            s = s..(' Z%+d'):format(adv_data.t_pos.z - hf_data.t_pos.z) --Negate because it's depth
        end
        insert_txt(txt, s)
    elseif hf_data.r_pos and adv_data.r_pos then --Use region
        local dx = hf_data.r_pos.x - adv_data.r_pos.x
        local dy = hf_data.r_pos.y - adv_data.r_pos.y
        table.insert(txt, NEWLINE)
        insert_txt(txt, 'target (region):')
        insert_txt(txt, compass(dx, dy))
        insert_txt(txt, ('X%+d Y%+d'):format(dx, dy))
    end --Else insufficient data
    return txt
end

local function region_pos_text(r_pos)
    if r_pos then
        return ('region: X%d Y%d'):format(r_pos.x, r_pos.x)
    end
end

local function travel_pos_text(t_pos)
    if t_pos then --Use Z if we have it. Negate because it's depth
        return 'travel: X'..t_pos.x..' Y'..t_pos.y..(t_pos.z and ' Z'..-t_pos.z or '')
    end
end

local function local_pos_text(pos)
    if pos then
        return ('local: X%d Y%d Z%d'):format(pos.x, pos.y, pos.z)
    end
end

local function adv_txt(adv_data, hf_data) --Text for adv info panel
    if not adv_data then
        return 'Error'
    end
    local txt = {'You'} --You, region, travel, local, relative
    insert_txt(txt, region_pos_text(adv_data.r_pos))
    insert_txt(txt, travel_pos_text(adv_data.t_pos))
    insert_txt(txt, local_pos_text(adv_data.pos))

    for _,str in ipairs(relative_txt(adv_data, hf_data)) do
        table.insert(txt, str)
    end
    return txt
end

-- Fns for target info panel --

local function hf_text(hf, hf_data) --Text for target info panel
    if not hf then --No target
        return ''
    end
    local txt = {} --Native, [translated], race, alive, location, [region,] [travel,] [local]

    local str = transName(hf.name, false)
    if str == '' then
        table.insert(txt, 'Anonymous')
    else --Both native and translation
        table.insert(txt, str) --TODO: Names get long, truncate somehow?
        insert_txt(txt, '"'..transName(hf.name, true)..'"')
    end
    str = get_race_name(hf)
    insert_txt(txt, str ~= '' and str or 'Force')

    local eternal --Can't reasonably die
    if hf.died_year ~= -1 then
        insert_txt(txt, {text='DEAD', pen=COLOR_RED})
    elseif hf.old_year == -1 and hf_data and hf_data.loc_type == LType.None then
        eternal = true
        insert_txt(txt, {text='ETERNAL', pen=COLOR_LIGHTBLUE})
    else
        insert_txt(txt, {text='ALIVE', pen=COLOR_LIGHTGREEN})
    end

    if not hf_data then --Insufficient data
        insert_txt(txt, {text='Missing', pen=COLOR_MAGENTA})
        return txt
    end

    if hf_data.loc_type == LType.None then --Everywhere or nowhere
        if eternal then
            insert_txt(txt, {text='Transcendent', pen=COLOR_YELLOW})
        else
            insert_txt(txt, {text='Missing', pen=COLOR_MAGENTA})
        end
    elseif hf_data.loc_type == LType.Local then
        insert_txt(txt, 'Nearby')
        insert_txt(txt, region_pos_text(hf_data.r_pos))
        insert_txt(txt, travel_pos_text(hf_data.t_pos))
        insert_txt(txt, local_pos_text(hf_data.pos))
    else
        if hf_data.loc_type == LType.Site then
            insert_txt(txt, 'At '..transName(hf_data.site.name, true))
        elseif hf_data.loc_type == LType.Army then
            insert_txt(txt, 'Traveling')
        elseif hf_data.loc_type == LType.Wild then
            insert_txt(txt, 'Wilderness')
        elseif hf_data.loc_type == LType.Under then
            insert_txt(txt, 'Underground')
        else --Undefined loc_type
            insert_txt(txt, 'Error')
        end
        insert_txt(txt, region_pos_text(hf_data.r_pos))
        insert_txt(txt, travel_pos_text(hf_data.t_pos))
    end
    return txt
end

-- Important stuff --

function AdvFindWindow:onRenderFrame(dc, rect)
    if not dfhack.world.isAdventureMode() then
        view:dismiss()
        qerror('Lost adventure mode! Terminating.')
    end
    self.super.onRenderFrame(self, dc, rect)

    local adv_panel = self.subviews.adv_panel
    local hf_panel = self.subviews.hf_panel

    local hf_data = get_hf_data(self.target_hf)
    adv_panel.subviews.adv_label:setText(adv_txt(get_adv_data(), hf_data))
    hf_panel.subviews.hf_label:setText(hf_text(self.target_hf, hf_data))

    adv_panel:updateLayout()
    hf_panel:updateLayout()
end

function AdvFindWindow:onResizeEnd(ok, frame) --Adjust list width
    self.subviews.sel_list.frame.w = frame.w-35
    self.subviews.sel_list:updateLayout()
end

function AdvFindWindow:on_submit_choice(sel, obj)
    self.target_hf = obj and obj[2] or nil
end

function AdvFindWindow:on_edit_change(txt) --Fill choices from search
    local hf_list = txt ~= '' and search_hf(search_str(txt)) or {}
    if next(hf_list) then
        self.subviews.sel_list:setChoices(hf_list)
        self.subviews.found_label:setText()
    else
        self.subviews.sel_list:setChoices()
        self.subviews.found_label:setText('No results')
    end
    self.subviews.found_label:updateLayout()
end

AdvFindScreen = defclass(AdvFindScreen, gui.ZScreen)
AdvFindScreen.ATTRS{
    focus_path = 'AdvFindScreen',
}

function AdvFindScreen:init()
    self:addviews{AdvFindWindow{}}
end

function AdvFindScreen:onDismiss()
    view = nil
end

if not dfhack.world.isAdventureMode() then
    qerror('Only works in adventure mode!')
end

view = view and view:raise() or AdvFindScreen{}:show()
