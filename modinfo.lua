name = "Action Queuer Plus"
author = "AlexXsWx"
version = "0.0.1"

description = (
    "Original author: simplex\n"..
    "Further work: xiaoXzzz & rezecib\n"..
    "\n"..
    "This is another modification by me on top of the \"ActionQueue(DST)\" v1.3.6.\n"..
    "\n"..
    "Allows queueing a sequence of actions (such as chopping, mining, picking up, planting etc)"..
    "by selecting targets within a bounding box, holding SHIFT (can be changed in config).\n"..
    "Supports auto repeat craft by SHIFT + click.\n"..
    "Supports auto collecting (disabled in config by default)."
)

-- TODO:
-- * Support patching boats (boat patch; trusty tape)
-- * Support werebeawer gnawing (trees, tree trunks, boulders)
-- * Support Wormwood planting seeds
-- * Support new farming? (use hoe, talk to plants)
-- * Zig-zag planting trees?
-- * Auto pick up seeds / scare birds / wait for butterflies
-- * World-aligned coords?
-- * Reduced cooldown on chopping burnt trees / digging up tree trunks
-- * Smarter/faster bulk pick-up?
-- * Fix gate door infinite loop?
-- * Option to disable flowers pick-up?
-- * While action queuer is active, don't auto submit new selection box until it's confirmed

api_version = 6
api_version_dst = 10

-- Compatible with the RoG and DST
dont_starve_compatible = false
shipwrecked_compatible = false
reign_of_giants_compatible = true
dst_compatible = true

all_clients_require_mod = false
client_only_mod = true

configuration_options = {
    {
        name = "autoCollect",
        label = "Auto collect",
        options = 
        {
            { description = "yes", data = "yes" },
            { description = "no",  data = "no"  },
        },
        default = "no"
    },
    {
        name = "repeatCraft",
        label = "Auto repeat craft",
        options = 
        {
            { description = "yes", data = "yes" },
            { description = "no",  data = "no"  },
        },
        default = "yes"
    },
    {
        name = "keyToUse",
        label = "Key to use",
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
            { description = "yes", data = "yes" },
            { description = "no",  data = "no"  },
        },
        default = "yes"
    },
}

local icon_stem = "modicon"
icon = icon_stem .. ".tex"
icon_atlas = icon_stem .. ".xml"

return icon_stem
