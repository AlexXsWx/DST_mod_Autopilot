name = "Autopilot"
author = "AlexXsWx"
version = "1.1.0"

description = (
    "This mod is a rewrite and extending of ActionQueue(DST) v1.3.6 by simplex and then xiaoXzzz\n"..
    "\n"..
    "Queue a sequence of actions (such as chopping, mining, picking up, planting etc) "..
    "by holding Shift (can be changed in config) and clicking on stuff or selecting area."
)

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
        hover = "This section lets you configure key bindings.",
    },
    {
        name = "keyToOpenOptions",
        label = "Toggle this menu",
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
            "Press again to close the configuration screen without applying changes."
        ),
    },
    {
        name = "keyToQueueActions",
        label = "Select target(s) / repeat action",
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
            "to queue actions."
        ),
    },
    {
        name = "altKeyToQueueActions",
        label = "Select target(s) / repeat action",
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
            "to queue actions. " ..
            "Alternative binding."
        ),
    },
    {
        name = "keyToDeselect",
        label = "Deselect target(s)",
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
            "to cancel all or some of previously queued actions."
        ),
    },
    {
        name = "keyToInterrupt",
        label = "Interrupt",
        options = 
        {
            { description = "None",  data = "none" },
            { description = "ESC",   data = "ESC"  },
            { description = "Ctrl",  data = "Ctrl" },
        },
        default = "ESC",
        hover = "Press this button to explicitly cancel queued actions.",
    },
    {
        name = "altKeyToInterrupt",
        label = "Interrupt",
        options = 
        {
            { description = "None",  data = "none" },
            { description = "ESC",   data = "ESC"  },
            { description = "Ctrl",  data = "Ctrl" },
        },
        default = "none",
        hover = (
            "Press this button to explicitly cancel queued actions.\n" ..
            "Alternative binding."
        ),
    },

    -- Double click

    {
        -- not a real options, just using it as separator
        name = "separatorDoubleClick",
        label = "DOUBLE CLICK                             ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = (
            "This section lets you configure double click to select or deselect " ..
            "entites of given type in given radius."
        ),
    },

    {
        name = "doubleClickMaxTimeSeconds",
        label = "Double click time",
        options = 
        {
            { description = "Disabled", data = 0.000 },
            { description = "150ms",    data = 0.150 },
            { description = "200ms",    data = 0.200 },
            { description = "250ms",    data = 0.250 },
            { description = "300ms",    data = 0.300 },
            { description = "350ms",    data = 0.350 },
            { description = "450ms",    data = 0.450 },
            { description = "500ms",    data = 0.500 },
            { description = "600ms",    data = 0.600 },
            { description = "700ms",    data = 0.700 },
            { description = "800ms",    data = 0.800 },
            { description = "900ms",    data = 0.900 },
            { description = "1000ms",   data = 1.000 },
        },
        default = 0.300,
        hover = (
            "Max amount of time (in milliseconds) that can pass between two mouse up events " ..
            "for them to be registered as a double click"
        ),
    },
    {
        name = "doubleClickSearchRadiusTiles",
        label = "Double click search radius",
        options = 
        {
            { description = "0.5 tiles", data = 0.5 },
            { description = "1 tile",    data = 1.0 },
            { description = "1.5 tiles", data = 1.5 },
            { description = "2.0 tiles", data = 2.0 },
            { description = "2.5 tiles", data = 2.5 },
            { description = "3.0 tiles", data = 3.0 },
            { description = "3.5 tiles", data = 3.5 },
            { description = "4.0 tiles", data = 4.0 },
            { description = "4.5 tiles", data = 4.5 },
            { description = "5.0 tiles", data = 5.0 },
            { description = "5.5 tiles", data = 5.5 },
            { description = "6.0 tiles", data = 6.0 },
            { description = "6.5 tiles", data = 6.5 },
            { description = "7.0 tiles", data = 7.0 },
            { description = "7.5 tiles", data = 7.5 },
            { description = "8.0 tiles", data = 8.0 },
        },
        default = 4.5,
        hover = "When double click happens, how far (in turf tiles) to search for same entity type",
    },

    -- Auto behaviors

    {
        -- not a real options, just using it as separator
        name = "separatorAutoBehaviors",
        label = "AUTO BEHAVIORS                  ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = "This section lets you configure automatic behaviors.",
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
        label = "Scare birds and pick up seeds",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "yes",
        hover = (
            "Should character automatically scare birds and pick up seeds " ..
            "when planting / deploying?"
        ),
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

    -- Pick up / pick filters
    {
        -- not a real options, just using it as separator
        name = "separatorPickUpPickFilters",
        label = "PICK UP / PICK FILTERS          ",
        options = { { description = "----------------------", data = -1 } },
        default = -1,
        hover = "This section lets you configure pick up filters.",
    },

    {
        name = "pickFlowersMode",
        label = "Flowers", -- also evil flowers, cave fern and succulent
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
        label = "Carrots", -- and carrat
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
        label = "Mandrakes",
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
        label = "Mushrooms", -- excluding mushroom farm and already picked ones
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
        label = "Twigs",
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
        label = "Rot",
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
        label = "Seeds",
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
        label = "Rocks",
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
        label = "Flint",
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
        label = "Tree blossom", -- both perishing and worldgen
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
        hover = "This section lets you configure miscellaneous filters.",
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
        hover = "This section is reserved for debug purposes.",
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
        hover = "Should print debug information in console?",
    },
}

local icon_stem = "modicon"
icon = icon_stem .. ".tex"
icon_atlas = icon_stem .. ".xml"

return icon_stem
