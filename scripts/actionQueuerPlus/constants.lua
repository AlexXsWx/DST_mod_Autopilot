local constants = {

    AUTO_COLLECT_RADIUS = 4,

    AUTO_COLLECT_ACTIONS = {
        [ACTIONS.CHOP] = true,
        [ACTIONS.MINE] = true,
        [ACTIONS.HAMMER] = true,
        [ACTIONS.DIG] = true
    },

    MANHATTAN_DISTANCE_TO_START_BOX_SELECTION = 64,

    GET_MOUSE_POS_PERIOD = 0.1,

    SELECTION_BOX_TINT = {1, 1, 1, 0.15}, -- RGBA

    UNSELECTABLE_TAGS = {"FX", "NOCLICK", "DECOR", "INLIMBO"},

    ALLOWED_ACTIONS = {
        [ACTIONS.PICK] = true,
        [ACTIONS.PICKUP] = true,
        [ACTIONS.TAKEITEM] = true,
        [ACTIONS.HARVEST] = true,

        [ACTIONS.CHOP] = true,
        [ACTIONS.MINE] = true,
        [ACTIONS.DIG] = true,
        [ACTIONS.HAMMER] = true,
        [ACTIONS.SHAVE] = true,
        [ACTIONS.REPAIR] = true,
        [ACTIONS.COOK] = true,
        
        [ACTIONS.GIVE] = true,
        [ACTIONS.USEITEM] = true,
        [ACTIONS.BAIT] = true,
        [ACTIONS.DRY] = true,
        [ACTIONS.FERTILIZE] = true,
        [ACTIONS.PLANT] = true,
        [ACTIONS.ADDFUEL] = true,
        [ACTIONS.ADDWETFUEL] = true,

        [ACTIONS.CHECKTRAP] = true,
        [ACTIONS.RESETMINE] = true,

        [ACTIONS.ACTIVATE] = true,
        [ACTIONS.TURNON] = true,
        [ACTIONS.TURNOFF] = true,

        [ACTIONS.EXTINGUISH] = true,
        [ACTIONS.NET] = true,

        -- New actions
        [ACTIONS.REPAIR_LEAK] = true,
        -- (e.g. heal abigal using glands)
        [ACTIONS.HEAL] = true,
        -- e.g. seeds
        [ACTIONS.EAT] = true,
    },

    ALLOWED_DEPLOY_MODES = {
        [DEPLOYMODE.PLANT] = true,
        [DEPLOYMODE.WALL] = true,
    },

    ALLOWED_DEPLOY_PREFABS = {
        ["trap_teeth"] = true,
        -- TODO: bramble trap?
    },
}

return constants
