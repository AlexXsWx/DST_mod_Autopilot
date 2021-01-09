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
-- * Support werebeawer gnawing (trees, tree trunks, boulders)
-- * Support Wormwood planting seeds
-- * Support new farming? (use hoe, talk to plants)
-- * Zig-zag planting trees? hex placing?
-- * Auto pick up seeds / scare birds / wait for butterflies / wait for shadow creatures?
-- * World-aligned coords?
-- * Reduced cooldown on chopping burnt trees / digging up tree trunks
-- * Smarter/faster bulk pick-up?
-- * Fix gate door infinite loop?
-- * While action queuer is active, don't auto submit new selection box until it's confirmed
-- * Repeat walk in direction
-- * Repeat walk along edge?
-- * Align player position to tile? (walk to) / increment steps? (to support dropping items at exact location)
-- * Button to auto pickup anything around?
-- * Don't interrupt current action when queing first one with shift+click
-- * Don't intrerupt action with LMB if user clicks on crafting tab?
-- * Button to deselect area
-- * Separate selection box actions and pick actions

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
    {
        name = "autoCollect",
        label = "Auto collect",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "no"
    },
    {
        name = "repeatCraft",
        label = "Auto repeat craft",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "yes"
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
        default = "Shift"
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
        default = "none"
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
        default = "none"
    },
    {
        name = "interruptOnMove",
        label = "Interrupt on move",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "yes"
    },
    {
        name = "pickFlowers",
        label = "Pick flowers",
        options = 
        {
            { description = "no",  data = "no"  },
            { description = "yes", data = "yes" },
        },
        default = "yes"
    },
}

local icon_stem = "modicon"
icon = icon_stem .. ".tex"
icon_atlas = icon_stem .. ".xml"

return icon_stem
