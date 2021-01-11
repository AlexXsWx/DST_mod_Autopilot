local Menu           = require "widgets/menu"
local Text           = require "widgets/text"
local Image          = require "widgets/image"
local Widget         = require "widgets/widget"
local TEMPLATES      = require "widgets/templates"

-- foward declaration --
local addRoot
local addBlack
local addShield
local addTitle
local addMenu
------------------------

local createScrollableWindow = function(params)
    -- addBlack({ parent = params.parent })

    local root = addRoot({ parent = params.parent })

    addShield({ parent = root })

    addTitle({
        parent = root,
        title = params.title
    })

    addMenu({
        parent   = root,
        onApply  = params.onApply,
        onCancel = params.onCancel,
    })

    local window = {
        root = root
    }

    return window
end

addRoot = function(params)
    local parent = params.parent

    local root = parent:AddChild(Widget("ROOT"))
    root:SetVAnchor(ANCHOR_MIDDLE)
    root:SetHAnchor(ANCHOR_MIDDLE)
    root:SetPosition(0, 0, 0)
    root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    return root
end

addBlack = function(params)
    local parent = params.parent

    local black = parent:AddChild(
        Image("images/global.xml", "square.tex")
    )
    black:SetVRegPoint(ANCHOR_MIDDLE)
    black:SetHRegPoint(ANCHOR_MIDDLE)
    black:SetVAnchor(ANCHOR_MIDDLE)
    black:SetHAnchor(ANCHOR_MIDDLE)
    black:SetScaleMode(SCALEMODE_FILLSCREEN)
    black:SetTint(0, 0, 0, 0.75)

    return black
end

addShield = function(params)
    local parent = params.parent

    local shield = parent:AddChild(TEMPLATES.CurlyWindow(40, 365, 1, 1, 67, -41))
    local fill = parent:AddChild(
        Image("images/fepanel_fills.xml", "panel_fill_tall.tex")
    )
    fill:SetScale(0.64, -0.57)
    fill:SetPosition(8, 12)
    shield:SetPosition(0, 0, 0)

    return shield, fill
end

addTitle = function(params)
    local parent   = params.parent
    local titleStr = params.title

    local title_max_w = 420
    local title_max_chars = 70
    local title = parent:AddChild(
        Text(BUTTONFONT, 45, " "..STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX)
    )
    local title_suffix_w = title:GetRegionSize()
    title:SetPosition(10, 190)
    title:SetColour(0, 0, 0, 1)
    if title_suffix_w < title_max_w then
        title:SetTruncatedString(
            titleStr,
            title_max_w - title_suffix_w,
            title_max_chars - 1 - STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX:len(),
            true
        )
        title:SetString(title:GetString().." "..STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX)
    else
        title:SetTruncatedString(
            STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX, title_max_w, title_max_chars, true
        )
    end

    return title
end

addMenu = function(params)
    local parent   = params.parent
    local onApply  = params.onApply
    local onCancel = params.onCancel

    local menu = parent:AddChild(Menu(nil, 0, true))
    local applybutton = menu:AddItem(
        STRINGS.UI.MODSSCREEN.APPLY,
        onApply,
        Vector3(165, -230, 0),
        "large"
    )
    local cancelbutton = menu:AddItem(
        STRINGS.UI.MODSSCREEN.BACK,
        onCancel,
        Vector3(-155, -230, 0)
    )
    applybutton:SetScale(0.7)
    cancelbutton:SetScale(0.7)
    menu:SetPosition(5, 0)

    return menu
end

return createScrollableWindow
