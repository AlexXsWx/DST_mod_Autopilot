name = "Action Queuer Plus"
author = "AlexXsWx"
version = "0.0.1"

description = (
    "Original author: simplex\n"..
    "Further work: xiaoXzzz & rezecib\n"..
    "\n"..
    "This is another modification by me on top of the \"ActionQueue(DST)\" v1.3.6.\n"..
    "\n"..
    "Allows queueing a sequence of actions (such as chopping, mining, picking up, planting etc) "..
    "by selecting targets within a bounding box, holding Shift (can be changed in config).\n"..
    "Supports auto repeat craft by Shift + click.\n"..
    "Supports auto collecting (disabled in config by default)."
)

-- TODO:
-- * Support new farming? (use hoe)
-- * Zig-zag planting trees? hex placing?
-- * Auto wait for butterflies / wait for shadow creatures?
-- * World-aligned coords?
-- * Smarter/faster bulk pick-up?
-- * Repeat walk in direction
-- * Repeat walk along edge?
-- * Align player position to tile? (walk to) / increment steps? (to support dropping items at exact location)
-- * Button to auto pickup anything around?
-- * Don't interrupt current action when queing first one with shift+click
-- * Separate selection box actions and pick actions
-- * only pick what's already in inventory
-- * Edge case: when using Shift, item shift on player should drop item but does nothing
-- * TODO: support cherry pick heaving
-- * Fix inconsistent beaver stump digging speed

api_version = 6 -- not sure about this one since DS is not supported
api_version_dst = 10

-- Only DST is supported
dst_compatible = true
dont_starve_compatible = false
shipwrecked_compatible = false
reign_of_giants_compatible = false

-- client only local mod
all_clients_require_mod = false
client_only_mod = true

configuration_options = {

    -- Key bindings

    {
        -- not a real options, just using it as separator
        name = "separatorKeyBindings",
        label = "KEY BINDINGS                        ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = "This section lets you change various key bindings",
    },
    {
        name = "keyToOpenOptions",
        label = "Key to toggle options screen",
        options = 
        {
            { description = "None",  data = "none" },
            { description = "Z",     data = "Z"    },
            { description = "X",     data = "X"    },
            { description = "C",     data = "C"    },
            { description = "V",     data = "V"    },
            { description = "B",     data = "B"    },
        },
        default = "C",
        hover = (
            "Allows to change all these options mid-game.\n" .. 
            "Press again to close options screen without applying changes"
        ),
    },
    {
        name = "keyToQueueActions",
        label = "Key to queue actions",
        options = 
        {
            { description = "Shift", data = "Shift" },
            { description = "Alt",   data = "Alt"   },
            { description = "Z",     data = "Z"     },
            { description = "X",     data = "X"     },
            { description = "C",     data = "C"     },
            { description = "V",     data = "V"     },
            { description = "B",     data = "B"     },
        },
        default = "Shift",
        hover = (
            "Hold this button while clicking or selecting area with left or right mouse button " ..
            "to queue actions"
        ),
    },
    {
        name = "altKeyToQueueActions",
        label = "Alternative key to queue actions",
        options = 
        {
            { description = "None",  data = "none"  },
            { description = "Shift", data = "Shift" },
            { description = "Alt",   data = "Alt"   },
            { description = "Z",     data = "Z"     },
            { description = "X",     data = "X"     },
            { description = "C",     data = "C"     },
            { description = "V",     data = "V"     },
            { description = "B",     data = "B"     },
        },
        default = "Z",
        hover = (
            "Hold this button while clicking or selecting area with left or right mouse button " ..
            "to queue actions"
        ),
    },
    {
        name = "keyToDeselect",
        label = "Key to deselect area",
        options = 
        {
            { description = "None",  data = "none" },
            { description = "ESC",   data = "ESC"  },
            { description = "Ctrl",  data = "Ctrl" },
            { description = "Alt",   data = "Alt"  },
            { description = "Z",     data = "Z"    },
            { description = "X",     data = "X"    },
            { description = "C",     data = "C"    },
            { description = "V",     data = "V"    },
            { description = "B",     data = "B"    },
        },
        default = "X",
        hover = (
            "Hold this button while clicking or selecting area with left or right mouse button " ..
            "to cancel all or some of previously queued actions"
        ),
    },
    {
        name = "keyToInterrupt",
        label = "Explicit key to interrupt",
        options = 
        {
            { description = "None",  data = "none" },
            { description = "ESC",   data = "ESC"  },
            { description = "Ctrl",  data = "Ctrl" },
        },
        default = "ESC",
        hover = "Press this button to cancel queued actions",
    },
    {
        name = "altKeyToInterrupt",
        label = "Alternative explicit key to interrupt",
        options = 
        {
            { description = "None",  data = "none" },
            { description = "ESC",   data = "ESC"  },
            { description = "Ctrl",  data = "Ctrl" },
        },
        default = "Ctrl",
        hover = "Press this button to cancel queued actions",
    },

    -- Auto behaviors

    {
        -- not a real options, just using it as separator
        name = "separatorAutoBehaviors",
        label = "AUTO BEHAVIORS                  ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = "This section lets you change auto behaviors",
    },
    {
        name = "interruptOnMove",
        label = "Interrupt on move",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "yes",
        hover = "Should movement with WASD interrupt queued actions?",
    },
    {
        name = "autoCollect",
        label = "Auto collect",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "no",
        hover = (
            "Should character pick up everything around itself " ..
            "after chopping, digging, mining and hammering?"
        ),
    },
    {
        name = "tryMakeDeployPossible",
        label = "Auto scare birds and pick seeds",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "yes",
        hover = (
            "Birds can interfere with possible plant/deploy location. " ..
            "Should character automatically scare them off and pick up seeds they leave? " ..
            "Only applies when performing queued plant/deploy actions "
        ),
    },
    {
        name = "positionIteratorName",
        label = "Position iterator",
        options = 
        {
            { description = "legacy", data = "legacy" },
            -- { description = "new",    data = "new"    },
        },
        default = "legacy",
        hover = "Algorithm used to select positions within selected area",
    },

    -- Pick up / pick filters
    {
        -- not a real options, just using it as separator
        name = "separatorPickUpPickFilters",
        label = "PICK UP / PICK FILTERS          ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = "This section lets you change pick up filters",
    },

    {
        name = "pickFlowersMode",
        label = "Pick flowers", -- also evil flowers, cave fern and succulent
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "no",
        hover = (
            "Should pick growing flowers (both normal and evil), succulents and cave ferns " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickCarrotsMode",
        label = "Pick carrots", -- and carrat
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "yes",
        hover = (
            "Should pick naturally growing carrots and carrats " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickMandrakesMode",
        label = "Pick mandrakes",
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "no",
        hover = (
            "Should pick planted mandrakes " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickMushroomsMode",
        label = "Pick mushrooms", -- excluding mushroom farm and already picked ones
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "yes",
        hover = (
            "Should pick natural growing mushrooms " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickTwigsMode",
        label = "Pick twigs",
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "yes",
        hover = (
            "Should pick or harvest twigs " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickRotMode",
        label = "Pick rot",
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "yes",
        hover = (
            "Should pick up rot " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickSeedsMode",
        label = "Pick seeds",
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "yes",
        hover = (
            "Should pick up generic seeds " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickRocksMode",
        label = "Pick rocks",
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "yes",
        hover = (
            "Should pick up rocks " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickFlintMode",
        label = "Pick flint",
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "yes",
        hover = (
            "Should pick up flint " ..
            "when selecting area or clicking directly?"
        ),
    },
    {
        name = "pickTreeBlossomMode",
        label = "Pick tree blossom", -- both perishing and worldgen
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "cherryPickOnly",
        hover = (
            "Should pick up tree blossom (both perishable and worldgen) " ..
            "when selecting area or clicking directly?"
        ),
    },

    -- misc filters

    {
        -- not a real options, just using it as separator
        name = "separatorMiscFilter",
        label = "MISC. FILTERS                           ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = "This section lets you change miscellaneous filters",
    },
    {
        name = "digUpSeeds",
        label = "Dig up planted seeds",
        options = 
        {
            { description = "no",               data = "no"             },
            { description = "Cherry pick only", data = "cherryPickOnly" },
            { description = "yes",              data = "yes"            },
        },
        default = "no",
        hover = (
            "Should dig up planted seeds " ..
            "when seleting area or clicking directly?"
        ),
    },
    {
        name = "digStumpsAsWerebeaver",
        label = "Dig stumps as werebeaver",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "yes",
        hover = "Should werebeaver spend time on digging up tree stumps?",
    },

    -- debug

    {
        -- not a real options, just using it as separator
        name = "separatorDebug",
        label = "DEBUG                                       ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = "This section is reserved for debug purposes",
    },

    {
        name = "logDebugEnabled",
        label = "Debug mode",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "no",
        hover = "Print debug information in console",
    },
}

local icon_stem = "modicon"
icon = icon_stem .. ".tex"
icon_atlas = icon_stem .. ".xml"

return icon_stem
