-- Multiline text editor for gui/journal
--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local wrapped_text = reqscript('internal/journal/wrapped_text')

local CLIPBOARD_MODE = {LOCAL = 1, LINE = 2}
local HISTORY_ENTRY = {
    TEXT_BLOCK = 1,
    WHITESPACE_BLOCK = 2,
    BACKSPACE = 2,
    DELETE = 3,
    OTHER = 4
}

TextEditorHistory = defclass(TextEditorHistory)

TextEditorHistory.ATTRS{
    history_size = 25,
}

function TextEditorHistory:init()
    self.past = {}
    self.future = {}
end

function TextEditorHistory:store(history_entry_type, text, cursor)
    local last_entry = self.past[#self.past]

    if not last_entry or history_entry_type == HISTORY_ENTRY.OTHER or
        last_entry.entry_type ~= history_entry_type then
        table.insert(self.past, {
            entry_type=history_entry_type,
            text=text,
            cursor=cursor
        })
    end

    self.future = {}

    if #self.past > self.history_size then
        table.remove(self.past, 1)
    end
end

function TextEditorHistory:undo(curr_text, curr_cursor)
    if #self.past == 0 then
        return nil
    end

    local history_entry = table.remove(self.past, #self.past)

    table.insert(self.future, {
        entry_type=OTHER,
        text=curr_text,
        cursor=curr_cursor
    })

    if #self.future > self.history_size then
        table.remove(self.future, 1)
    end

    return history_entry
end

function TextEditorHistory:redo(curr_text, curr_cursor)
    if #self.future == 0 then
        return true
    end

    local history_entry = table.remove(self.future, #self.future)

    table.insert(self.past, {
        entry_type=OTHER,
        text=curr_text,
        cursor=curr_cursor
    })

    if #self.past > self.history_size then
        table.remove(self.past, 1)
    end

    return history_entry
end

TextEditor = defclass(TextEditor, widgets.Panel)

TextEditor.ATTRS{
    init_text = '',
    init_cursor = DEFAULT_NIL,
    text_pen = COLOR_LIGHTCYAN,
    ignore_keys = {'STRING_A096'},
    select_pen = COLOR_CYAN,
    on_text_change = DEFAULT_NIL,
    on_cursor_change = DEFAULT_NIL,
    one_line_mode = false,
    debug = false
}

function TextEditor:init()
    self.render_start_line_y = 1

    self:addviews{
        TextEditorView{
            view_id='text_area',
            frame={l=0,r=3,t=0},
            text=self.init_text,

            text_pen=self.text_pen,
            ignore_keys=self.ignore_keys,
            select_pen=self.select_pen,
            debug=self.debug,
            one_line_mode=self.one_line_mode,

            on_text_change=function (val)
                self:updateLayout()
                if self.on_text_change then
                    self.on_text_change(val)
                end
            end,
            on_cursor_change=self:callback('onCursorChange')
        },
        widgets.Scrollbar{
            view_id='scrollbar',
            frame={r=0,t=1},
            on_scroll=self:callback('onScrollbar'),
            visible=not self.one_line_mode
        }
    }
    self:setFocus(true)
end

function TextEditor:getText()
    return self.subviews.text_area.text
end

function TextEditor:getCursor()
    return self.subviews.text_area.cursor
end

function TextEditor:onCursorChange(cursor)
    local x, y = self.subviews.text_area.wrapped_text:indexToCoords(
        self.subviews.text_area.cursor
    )

    if y >= self.render_start_line_y + self.subviews.text_area.frame_body.height then
        self:updateScrollbar(
            y - self.subviews.text_area.frame_body.height + 1
        )
    elseif  (y < self.render_start_line_y) then
        self:updateScrollbar(y)
    end

    if self.on_cursor_change then
        self.on_cursor_change(cursor)
    end
end

function TextEditor:scrollToCursor(cursor_offset)
    if self.subviews.scrollbar.visible then
        local _, cursor_liny_y = self.subviews.text_area.wrapped_text:indexToCoords(
            cursor_offset
        )
        self:updateScrollbar(cursor_liny_y)
    end
end

function TextEditor:setCursor(cursor_offset)
    return self.subviews.text_area:setCursor(cursor_offset)
end

function TextEditor:getPreferredFocusState()
    return self.parent_view.focus
end

function TextEditor:postUpdateLayout()
    self:updateScrollbar(self.render_start_line_y)

    if self.subviews.text_area.cursor == nil then
        local cursor = self.init_cursor or #self.init_text + 1
        self.subviews.text_area:setCursor(cursor)
        self:scrollToCursor(cursor)
    end
end

function TextEditor:onScrollbar(scroll_spec)
    local height = self.subviews.text_area.frame_body.height

    local render_start_line = self.render_start_line_y
    if scroll_spec == 'down_large' then
        render_start_line = render_start_line + math.ceil(height / 2)
    elseif scroll_spec == 'up_large' then
        render_start_line = render_start_line - math.ceil(height / 2)
    elseif scroll_spec == 'down_small' then
        render_start_line = render_start_line + 1
    elseif scroll_spec == 'up_small' then
        render_start_line = render_start_line - 1
    else
        render_start_line = tonumber(scroll_spec)
    end

    self:updateScrollbar(render_start_line)
end

function TextEditor:updateScrollbar(scrollbar_current_y)
    local lines_count = #self.subviews.text_area.wrapped_text.lines

    local render_start_line_y = (math.min(
        #self.subviews.text_area.wrapped_text.lines - self.subviews.text_area.frame_body.height + 1,
        math.max(1, scrollbar_current_y)
    ))

    self.subviews.scrollbar:update(
        render_start_line_y,
        self.frame_body.height,
        lines_count
    )

    if (self.frame_body.height >= lines_count) then
        render_start_line_y = 1
    end

    self.render_start_line_y = render_start_line_y
    self.subviews.text_area:setRenderStartLineY(self.render_start_line_y)
end

function TextEditor:renderSubviews(dc)
    self.subviews.text_area.frame_body.y1 = self.frame_body.y1-(self.render_start_line_y - 1)

    TextEditor.super.renderSubviews(self, dc)
end

function TextEditor:onInput(keys)
    if (self.subviews.scrollbar.is_dragging) then
        return self.subviews.scrollbar:onInput(keys)
    end

    if keys._MOUSE_L and self:getMousePos() then
        self:setFocus(true)
    end

    return TextEditor.super.onInput(self, keys)
end

TextEditorView = defclass(TextEditorView, widgets.Widget)

TextEditorView.ATTRS{
    text = '',
    text_pen = COLOR_LIGHTCYAN,
    ignore_keys = {'STRING_A096'},
    pen_selection = COLOR_CYAN,
    on_text_change = DEFAULT_NIL,
    on_cursor_change = DEFAULT_NIL,
    enable_cursor_blink = true,
    debug = false,
    one_line_mode = false,
    history_size = 10,
}

function TextEditorView:init()
    self.sel_end = nil
    self.clipboard = nil
    self.clipboard_mode = CLIPBOARD_MODE.LOCAL
    self.render_start_line_y = 1

    self.cursor = nil

    self.main_pen = dfhack.pen.parse({
        fg=self.text_pen,
        bg=COLOR_RESET,
        bold=true
    })
    self.sel_pen = dfhack.pen.parse({
        fg=self.text_pen,
        bg=self.pen_selection,
        bold=true
    })

    self.text = self:normalizeText(self.text)

    self.wrapped_text = wrapped_text.WrappedText{
        text=self.text,
        wrap_width=256
    }

    self.history = TextEditorHistory{history_size=self.history_size}
end

function TextEditorView:normalizeText(text)
    if self.one_line_mode then
        return text:gsub("\r?\n", "")
    end

    return text
end

function TextEditorView:setRenderStartLineY(render_start_line_y)
    self.render_start_line_y = render_start_line_y
end

function TextEditorView:getPreferredFocusState()
    return true
end

function TextEditorView:postComputeFrame()
    self:recomputeLines()
end

function TextEditorView:recomputeLines()
    self.wrapped_text:update(
        self.text,
        -- something cursor '_' need to be add at the end of a line
        self.frame_body.width - 1
    )
end

function TextEditorView:setCursor(cursor_offset)
    self.cursor = math.max(
        1,
        math.min(#self.text + 1, cursor_offset)
    )

    if self.debug then
        print('cursor', self.cursor)
    end

    self.sel_end = nil
    self.last_cursor_x = nil

    if self.on_cursor_change then
        self.on_cursor_change(self.cursor)
    end
end

function TextEditorView:setSelection(from_offset, to_offset)
    -- text selection is always start on self.cursor and on self.sel_end
    self:setCursor(from_offset)
    self.sel_end = to_offset

    if self.debug and to_offset then
        print('sel_end', to_offset)
    end
end

function TextEditorView:hasSelection()
    return not not self.sel_end
end

function TextEditorView:eraseSelection()
    if (self:hasSelection()) then
        local from, to = self.cursor, self.sel_end
        if (from > to) then
            from, to = to, from
        end

        local new_text = self.text:sub(1, from - 1) .. self.text:sub(to + 1)
        self:setText(new_text)

        self:setCursor(from)
        self.sel_end = nil
    end
end

function TextEditorView:setClipboard(text)
    dfhack.internal.setClipboardTextCp437Multiline(text)
end

function TextEditorView:copy()
    if self.sel_end then
        self.clipboard_mode =  CLIPBOARD_MODE.LOCAL

        local from = self.cursor
        local to = self.sel_end

        if from > to then
            from, to = to, from
        end

        self:setClipboard(self.text:sub(from, to))

        return from, to
    else
        self.clipboard_mode = CLIPBOARD_MODE.LINE

        local curr_line = self.text:sub(
            self:lineStartOffset(),
            self:lineEndOffset()
        )
        if curr_line:sub(-1,-1) ~= NEWLINE then
            curr_line = curr_line .. NEWLINE
        end

        self:setClipboard(curr_line)

        return self:lineStartOffset(), self:lineEndOffset()
    end
end

function TextEditorView:cut()
    local from, to = self:copy()
    if not self:hasSelection() then
        self:setSelection(from, to)
    end
    self:eraseSelection()
end

function TextEditorView:paste()
    local clipboard_lines = dfhack.internal.getClipboardTextCp437Multiline()
    local clipboard = table.concat(clipboard_lines, '\n')
    if clipboard then
        if self.clipboard_mode == CLIPBOARD_MODE.LINE and not self:hasSelection() then
            local origin_offset = self.cursor
            self:setCursor(self:lineStartOffset())
            self:insert(clipboard)
            self:setCursor(#clipboard + origin_offset)
        else
            self:eraseSelection()
            self:insert(clipboard)
        end

    end
end

function TextEditorView:setText(text)
    local changed = self.text ~= text
    self.text = self:normalizeText(text)

    self:recomputeLines()

    if changed and self.on_text_change then
        self.on_text_change(text)
    end
end

function TextEditorView:insert(text)
    self:eraseSelection()
    local new_text =
        self.text:sub(1, self.cursor - 1) ..
        text ..
        self.text:sub(self.cursor)

    self:setText(new_text)
    self:setCursor(self.cursor + #text)
end

function TextEditorView:onRenderBody(dc)
    dc:pen(self.main_pen)

    local max_width = dc.width
    local new_line = self.debug and NEWLINE or ''

    local lines_to_render = math.min(
        dc.height,
        #self.wrapped_text.lines - self.render_start_line_y + 1
    )

    dc:seek(0, self.render_start_line_y - 1)
    for i = self.render_start_line_y, self.render_start_line_y + lines_to_render - 1 do
        -- do not render new lines symbol
        local line = self.wrapped_text.lines[i]:gsub(NEWLINE, new_line)
        dc:string(line)
        dc:newline()
    end

    local show_focus = not self.enable_cursor_blink
        or (
            not self:hasSelection()
            and self.parent_view.focus
            and gui.blink_visible(530)
        )

    if (show_focus) then
        local x, y = self.wrapped_text:indexToCoords(self.cursor)
        dc:seek(x - 1, y - 1)
            :char('_')
    end

    if self:hasSelection() then
        local sel_new_line = self.debug and PERIOD or ''
        local from, to = self.cursor, self.sel_end
        if (from > to) then
            from, to = to, from
        end

        local from_x, from_y = self.wrapped_text:indexToCoords(from)
        local to_x, to_y = self.wrapped_text:indexToCoords(to)

        local line = self.wrapped_text.lines[from_y]
            :sub(from_x, to_y == from_y and to_x or nil)
            :gsub(NEWLINE, sel_new_line)

        dc:pen(self.sel_pen)
            :seek(from_x - 1, from_y - 1)
            :string(line)

        for y = from_y + 1, to_y - 1 do
            line = self.wrapped_text.lines[y]:gsub(NEWLINE, sel_new_line)
            dc:seek(0, y - 1)
                :string(line)
        end

        if (to_y > from_y) then
            local line = self.wrapped_text.lines[to_y]
                :sub(1, to_x)
                :gsub(NEWLINE, sel_new_line)
            dc:seek(0, to_y - 1)
                :string(line)
        end

        dc:pen({fg=self.text_pen, bg=COLOR_RESET})
    end

    if self.debug then
        local cursor_char = self:charAtCursor()
        local x, y = self.wrapped_text:indexToCoords(self.cursor)
        local debug_msg = string.format(
            'x: %s y: %s ind: %s #line: %s char: %s hist-: %s hist+: %s',
            x,
            y,
            self.cursor,
            self:lineEndOffset() - self:lineStartOffset(),
            (cursor_char == NEWLINE and 'NEWLINE') or
            (cursor_char == ' ' and 'SPACE') or
            (cursor_char == '' and 'nil') or
            cursor_char,
            #self.history.past,
            #self.history.future
        )
        local sel_debug_msg = self.sel_end and string.format(
            'sel_end: %s',
            self.sel_end
        ) or ''

        dc:pen({fg=COLOR_LIGHTRED, bg=COLOR_RESET})
            :seek(0, self.parent_view.frame_body.height + self.render_start_line_y - 2)
            :string(debug_msg)
            :seek(0, self.parent_view.frame_body.height + self.render_start_line_y - 3)
            :string(sel_debug_msg)
    end
end

function TextEditorView:charAtCursor()
    return self.text:sub(self.cursor, self.cursor)
end

function TextEditorView:getMultiLeftClick(x, y)
    if self.last_click then
        local from_last_click_ms = dfhack.getTickCount() - self.last_click.tick

        if (
            self.last_click.x ~= x or
            self.last_click.y ~= y or
            from_last_click_ms > widgets.DOUBLE_CLICK_MS
        ) then
            self.clicks_count = 0;
        end
    end

    return self.clicks_count or 0
end

function TextEditorView:triggerMultiLeftClick(x, y)
    local clicks_count = self:getMultiLeftClick(x, y)

    self.clicks_count = clicks_count + 1
    if (self.clicks_count >= 4) then
        self.clicks_count = 1
    end

    self.last_click = {
        tick=dfhack.getTickCount(),
        x=x,
        y=y,
    }
    return self.clicks_count
end

function TextEditorView:currentSpacesRange()
    -- select "word" only from spaces
    local prev_word_end, _  = self.text
        :sub(1, self.cursor)
        :find('[^%s]%s+$')
    local _, next_word_start = self.text:find('%s[^%s]', self.cursor)

    return prev_word_end + 1 or 1, next_word_start - 1 or #self.text
end

function TextEditorView:currentWordRange()
    -- select current word
    local _, prev_word_end = self.text
        :sub(1, self.cursor - 1)
        :find('.*[%s,."\']')
    local next_word_start, _  = self.text:find('[%s,."\']', self.cursor)

    return (prev_word_end or 0) + 1, (next_word_start or #self.text + 1) - 1
end

function TextEditorView:lineStartOffset(offset)
    local loc_offset = offset or self.cursor
    return self.text:sub(1, loc_offset - 1):match(".*\n()") or 1
end

function TextEditorView:lineEndOffset(offset)
    local loc_offset = offset or self.cursor
    return self.text:find("\n", loc_offset) or #self.text + 1
end

function TextEditorView:wordStartOffset(offset)
    return self.text
        :sub(1, offset or self.cursor - 1)
        :match('.*%s()[^%s]') or 1
end

function TextEditorView:wordEndOffset(offset)
    return self.text
        :match(
            '%s*[^%s]*()',
            offset or self.cursor
        ) or #self.text + 1
end

function TextEditorView:onInput(keys)
    for _,ignore_key in ipairs(self.ignore_keys) do
        if keys[ignore_key] then
            return false
        end
    end

    if self:onMouseInput(keys) then
        return true
    elseif self:onHistoryInput(keys) then
        return true
    elseif self:onTextManipulationInput(keys) then
        return true
    elseif self:onCursorInput(keys) then
        return true
    elseif keys.CUSTOM_CTRL_C then
        self:copy()
        return true
    elseif keys.CUSTOM_CTRL_X then
        self:cut()
        self.history:store(HISTORY_ENTRY.OTHER, self.text, self.cursor)
        return true
    elseif keys.CUSTOM_CTRL_V then
        self:paste()
        self.history:store(HISTORY_ENTRY.OTHER, self.text, self.cursor)
        return true
    else
        return TextEditor.super.onInput(self, keys)
    end
end

function TextEditorView:onHistoryInput(keys)
    if keys.CUSTOM_CTRL_Z then
        local history_entry = self.history:undo(self.text, self.cursor)

        if history_entry then
            self:setText(history_entry.text)
            self:setCursor(history_entry.cursor)
        end

        return true
    elseif keys.CUSTOM_CTRL_Y then
        local history_entry = self.history:redo(self.text, self.cursor)

        if history_entry then
            self:setText(history_entry.text)
            self:setCursor(history_entry.cursor)
        end

        return true
    end
end

function TextEditorView:onMouseInput(keys)
    if keys._MOUSE_L then
        local mouse_x, mouse_y = self:getMousePos()
        if mouse_x and mouse_y then

            local clicks_count = self:triggerMultiLeftClick(
                mouse_x + 1,
                mouse_y + 1
            )
            if clicks_count == 3 then
                self:setSelection(
                    self:lineStartOffset(),
                    self:lineEndOffset()
                )
            elseif clicks_count == 2 then
                local cursor_char = self:charAtCursor()

                local is_white_space = (
                    cursor_char == ' ' or cursor_char == NEWLINE
                )

                local from, to
                if is_white_space then
                    from, to = self:currentSpacesRange()
                else
                    from, to = self:currentWordRange()
                end

                self:setSelection(from, to)
            else
                self:setCursor(self.wrapped_text:coordsToIndex(
                    mouse_x + 1,
                    mouse_y + 1
                ))
            end

            return true
        end

    elseif keys._MOUSE_L_DOWN then

        local mouse_x, mouse_y = self:getMousePos()
        if mouse_x and mouse_y then
            if (self:getMultiLeftClick(mouse_x + 1, mouse_y + 1) > 1) then
                return true
            end

            local offset = self.wrapped_text:coordsToIndex(
                mouse_x + 1,
                mouse_y + 1
            )

            if self.cursor ~= offset then
                self:setSelection(self.cursor, offset)
            else
                self.sel_end = nil
            end

            return true
        end
    end
end

function TextEditorView:onCursorInput(keys)
    if keys.KEYBOARD_CURSOR_LEFT then
        self:setCursor(self.cursor - 1)
        return true
    elseif keys.KEYBOARD_CURSOR_RIGHT then
        self:setCursor(self.cursor + 1)
        return true
    elseif keys.KEYBOARD_CURSOR_UP then
        local x, y = self.wrapped_text:indexToCoords(self.cursor)
        local last_cursor_x = self.last_cursor_x or x
        local offset = y > 1 and
            self.wrapped_text:coordsToIndex(last_cursor_x, y - 1) or
            1
        self:setCursor(offset)
        self.last_cursor_x = last_cursor_x
        return true
    elseif keys.KEYBOARD_CURSOR_DOWN then
        local x, y = self.wrapped_text:indexToCoords(self.cursor)
        local last_cursor_x = self.last_cursor_x or x
        local offset = y < #self.wrapped_text.lines and
            self.wrapped_text:coordsToIndex(last_cursor_x, y + 1) or
            #self.text + 1
        self:setCursor(offset)
        self.last_cursor_x = last_cursor_x
        return true
    elseif keys.CUSTOM_CTRL_HOME then
        self:setCursor(1)
        return true
    elseif keys.CUSTOM_CTRL_END then
        -- go to text end
        self:setCursor(#self.text + 1)
        return true
    elseif keys.CUSTOM_CTRL_LEFT then
        -- back one word
        local word_start = self:wordStartOffset()
        self:setCursor(word_start)
        return true
    elseif keys.CUSTOM_CTRL_RIGHT then
        -- forward one word
        local word_end = self:wordEndOffset()
        self:setCursor(word_end)
        return true
    elseif keys.CUSTOM_HOME then
        -- line start
        self:setCursor(
            self:lineStartOffset()
        )
        return true
    elseif keys.CUSTOM_END then
        -- line end
        self:setCursor(
            self:lineEndOffset()
        )
        return true
    end
end

function TextEditorView:onTextManipulationInput(keys)
    if keys.SELECT then
        -- handle enter
        if not self.one_line_mode then
            self.history:store(
                HISTORY_ENTRY.WHITESPACE_BLOCK,
                self.text,
                self.cursor
            )
            self:insert(NEWLINE)
        end

        return true

    elseif keys._STRING then
        if keys._STRING == 0 then
            -- handle backspace
            self.history:store(HISTORY_ENTRY.BACKSPACE, self.text, self.cursor)

            if (self:hasSelection()) then
                self:eraseSelection()
            else
                if (self.cursor == 1) then
                    return true
                end

                self:setSelection(
                    self.cursor - 1,
                    self.cursor - 1
                )
                self:eraseSelection()
            end

        else
            local cv = string.char(keys._STRING)

            if (self:hasSelection()) then
                self.history:store(HISTORY_ENTRY.OTHER, self.text, self.cursor)
                self:eraseSelection()
            else
                local entry_type = cv == ' ' and HISTORY_ENTRY.WHITESPACE_BLOCK
                    or HISTORY_ENTRY.TEXT_BLOCK
                self.history:store(entry_type, self.text, self.cursor)
            end

            self:insert(cv)
        end

        return true
    elseif keys.CUSTOM_CTRL_A then
        -- select all
        self:setSelection(1, #self.text)
        return true
    elseif keys.CUSTOM_CTRL_U then
        -- delete current line
        self.history:store(HISTORY_ENTRY.OTHER, self.text, self.cursor)

        if (self:hasSelection()) then
            -- delete all lines that has selection
            self:setSelection(
                self:lineStartOffset(self.cursor),
                self:lineEndOffset(self.sel_end)
            )
            self:eraseSelection()
        else
            self:setSelection(
                self:lineStartOffset(),
                self:lineEndOffset()
            )
            self:eraseSelection()
        end

        return true
    elseif keys.CUSTOM_CTRL_K then
        -- delete from cursor to end of current line
        self.history:store(HISTORY_ENTRY.OTHER, self.text, self.cursor)

        local line_end = self:lineEndOffset(self.sel_end or self.cursor) - 1
        self:setSelection(
            self.cursor,
            math.max(line_end, self.cursor)
        )
        self:eraseSelection()

        return true
    elseif keys.CUSTOM_DELETE then
        self.history:store(HISTORY_ENTRY.DELETE, self.text, self.cursor)

        if (self:hasSelection()) then
            self:eraseSelection()
        else
            self:setText(
                self.text:sub(1, self.cursor - 1) ..
                self.text:sub(self.cursor + 1)
            )
        end

        return true
    elseif keys.CUSTOM_CTRL_W then
        -- delete one word backward
        self.history:store(HISTORY_ENTRY.OTHER, self.text, self.cursor)

        if not self:hasSelection() and self.cursor ~= 1 then
            self:setSelection(
                self:wordStartOffset(),
                math.max(self.cursor - 1, 1)
            )
        end
        self:eraseSelection()

        return true
    end
end
