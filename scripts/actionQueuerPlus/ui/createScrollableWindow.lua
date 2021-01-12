-- local Menu           = require "widgets/menu"
local Text           = require "widgets/text"
-- local Image          = require "widgets/image"
local Widget         = require "widgets/widget"
local TEMPLATES      = require "widgets/redux/templates"

-- foward declaration --
local addDialog
local addHeader
local addTitle
------------------------

local createScrollableWindow = function(params)

    params.parent:AddChild(TEMPLATES.BackgroundTint())

    local root = params.parent:AddChild(TEMPLATES.ScreenRoot())

    local dialog = addDialog({
        parent    = root,
        itemWidth = params.itemWidth,
        onApply   = params.onApply,
        onCancel  = params.onCancel,
    })

    local header = addHeader({ parent = dialog })

    addTitle({
        parent = header,
        title = params.title
    })

    local window = {
        root = root,
        dialog = dialog,
        header = header,
    }

    return window
end

addDialog = function(params)
    local parent    = params.parent
    local itemWidth = params.itemWidth
    local onApply   = params.onApply
    local onCancel  = params.onCancel

    local buttons = {
        { text = STRINGS.UI.MODSSCREEN.APPLY, cb = onApply  },
        { text = STRINGS.UI.MODSSCREEN.BACK,  cb = onCancel },
    }

    local dialog = parent:AddChild(
        TEMPLATES.RectangleWindow(itemWidth + 20, 580, nil, buttons)
    )

    return dialog
end

addHeader = function(params)
    local parent = params.parent

    local header = parent:AddChild(Widget("option_header"))
    header:SetPosition(0, 270)

    return header
end

addTitle = function(params)
    local parent   = params.parent
    local titleStr = params.title

    local suffix = STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX

    local title_max_w = 420
    local title_max_chars = 70
    local title = parent:AddChild(
        Text(HEADERFONT, 28, " "..suffix)
    )
    local title_suffix_w = title:GetRegionSize()
    title:SetColour(UICOLOURS.GOLD_SELECTED)
    if title_suffix_w < title_max_w then
        title:SetTruncatedString(
            titleStr,
            title_max_w - title_suffix_w,
            title_max_chars - 1 - suffix:len(),
            true
        )
        title:SetString(
            title:GetString().." "..suffix
        )
    else
        -- translation was so long we can't fit any more text
        title:SetTruncatedString(
            suffix,
            title_max_w,
            title_max_chars,
            true
        )
    end

    return title
end

return createScrollableWindow
