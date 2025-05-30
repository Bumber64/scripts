-- lists books that contain secrets of life and death.

local argparse = require("argparse")

function get_book_interactions(item)
    local title, book_interactions = nil, {}
    for _, improvement in ipairs(item.improvements) do
        if improvement._type == df.itemimprovement_pagesst or
           improvement._type == df.itemimprovement_writingst then
            for _, content_id in ipairs(improvement.contents) do
                local written_content = df.written_content.find(content_id)
                if not written_content then goto continue end

                title = written_content.title
                for _, ref in ipairs (written_content.refs) do
                    if ref._type == df.general_ref_interactionst then
                        local interaction = df.interaction.find(ref.interaction_id)
                        table.insert(book_interactions, interaction)
                    end
                end
                ::continue::
            end
        end
    end

    return title, book_interactions
end

function check_slab_secrets(item)
    local type_id = item.engraving_type
    local type = df.slab_engraving_type[type_id]
    return type == "Secrets"
end

function get_item_artifact(item)
    for _, ref in ipairs(item.general_refs) do
        if ref._type == df.general_ref_is_artifactst then
            return df.artifact_record.find(ref.artifact_id)
        end
    end
end

function print_interactions(interactions)
    for _, interaction in ipairs(interactions) do
        -- Search interaction.str for the tag [CDI:ADV_NAME:<string>]
        -- for example: [CDI:ADV_NAME:Raise fetid corpse]
        for _, str in ipairs(interaction.str) do
            local _, e = string.find(str.value, "ADV_NAME")
            if e then
                print("    " .. string.sub(str.value, e + 2, #str.value - 1))
            end
        end
    end
end

function necronomicon(include_slabs)
    if include_slabs then
        print("Slabs:")
        print()
        for _, item in ipairs(df.global.world.items.other.SLAB) do
            if check_slab_secrets(item) then
                local artifact = get_item_artifact(item)
                local name = dfhack.translation.translateName(artifact.name)
                print("  " .. dfhack.df2console(name))
            end
        end
        print()
    end
    print("Books and Scrolls:")
    print()
    for _, vec in ipairs{df.global.world.items.other.BOOK, df.global.world.items.other.TOOL} do
        for _, item in ipairs(vec) do
            local title, interactions = get_book_interactions(item)

            if next(interactions) ~= nil then
                print("  " .. dfhack.df2console(title))
                print_interactions(interactions)
                print()
            end
        end
    end
end

function necronomicon_world(include_slabs)
    if include_slabs then
        print("Slabs:")
        print()
        for _,rec in ipairs(df.global.world.artifacts.all) do
            if df.item_slabst:is_instance(rec.item) and check_slab_secrets(rec.item) then
                print(dfhack.df2console(dfhack.translation.translateName(rec.name)))
            end
        end
        print()
    end
    print("Books and Scrolls:")
    print()
    for _,rec in ipairs(df.global.world.artifacts.all) do
        if df.item_bookst:is_instance(rec.item) or df.item_toolst:is_instance(rec.item) then
            local title, interactions = get_book_interactions(rec.item)

            if next(interactions) then
                print("  " .. dfhack.df2console(title))
                print_interactions(interactions)
                print()
            end
        end
    end
end

local help = false
local include_slabs, scan_world = false, false
local args = argparse.processArgsGetopt({...}, {
    {"s", "include-slabs", handler=function() include_slabs = true end},
    {"w", "world", handler=function() scan_world = true end},
    {"h", "help", handler=function() help = true end}
})

local cmd = args[1]

if help or cmd == "help" then
    print(dfhack.script_help())
elseif not cmd then
    if scan_world then
        necronomicon_world(include_slabs)
    else
        necronomicon(include_slabs)
    end
else
    print(('necronomicon: Invalid argument: "%s"'):format(cmd))
end
