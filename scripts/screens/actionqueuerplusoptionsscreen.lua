local Screen         = require "widgets/screen"
local Text           = require "widgets/text"
local Spinner        = require "widgets/spinner"
local Widget         = require "widgets/widget"
local ScrollableList = require "widgets/scrollablelist"

local createScrollableWindow = require "actionQueuerPlus/ui/createScrollableWindow"

-- forward declaration --
local OptionsScreen_Apply
local getModOptions
local collectSettings
local createOptionsScrollList
local createOptionWidgets
-------------------------

local clientConfig = true

local OptionsScreen = Class(Screen, function(self, modname, scrollViewOffset, onClose)
    Screen._ctor(self, "ActionQueuerPlusOptionsScreen")

    self._onClose = onClose
    self._modname = modname

    self._options = getModOptions(modname)

    self._dirty = false
    local markDirty = function()
        self._dirty = true
    end

    local window = createScrollableWindow({
        parent = self,
        title = "Action Queuer Plus Options",
        onApply  = function() OptionsScreen_Apply(self) end,
        onCancel = function() self:Close() end,
    })

    self._optionsScrollList = createOptionsScrollList(
        window.root,
        self._options,
        scrollViewOffset,
        markDirty
    )
end)

function OptionsScreen:OnControl(control, down)
    if OptionsScreen._base.OnControl(self, control, down) then
        return true
    end
    
    if not down and (
        control == CONTROL_PAUSE or
        control == CONTROL_CANCEL or
        control == CONTROL_MENU_MISC_3
    ) then
        self:Close()
        return true
    end
end

function OptionsScreen:Close(optHadEffect)
    self._onClose(
        self._optionsScrollList.view_offset,
        optHadEffect or false
    )
    TheFrontEnd:PopScreen()
end

OptionsScreen_Apply = function(self)
    if not self._dirty then
        self:Close()
        return    
    end

    local settings = collectSettings(self._options)
    KnownModIndex:SaveConfigurationOptions(
        function() 
            self._dirty = false
            self:Close(true)
        end,
        self._modname,
        settings,
        clientConfig
    )
end

--

getModOptions = function(modname)
    local config = KnownModIndex:LoadModConfigurationOptions(
        modname,
        clientConfig
    )

    local options = {}

    if config and type(config) == "table" then
        for i, v in ipairs(config) do
            -- Only show the option if it matches our format exactly
            if v.name and v.options and (v.saved ~= nil or v.default ~= nil) then
                local _value = v.saved
                if _value == nil then _value = v.default end
                table.insert(options, {
                    name    = v.name,
                    label   = v.label,
                    options = v.options,
                    default = v.default,
                    value   = _value,
                    hover   = v.hover
                })
            end
        end
    end

    return options
end

collectSettings = function(options)
    local settings = nil
    for i, v in pairs(options) do
        if not settings then settings = {} end
        table.insert(settings, {
            name    = v.name,
            label   = v.label,
            options = v.options,
            default = v.default,
            saved   = v.value
        })
    end
    return settings
end

-- UI stuff

createOptionsScrollList = function(parent, options, scrollViewOffset, markDirty)
    local optionsPanel = parent:AddChild(Widget("optionspanel"))  
    optionsPanel:SetPosition(0, -20)

    local scrollList = optionsPanel:AddChild(
        ScrollableList({}, 450, 350, 40, 10)
    )

    local optionWidgets = createOptionWidgets(options, markDirty)

    scrollList:SetList(optionWidgets)
    if scrollList.scroll_bar_line:IsVisible() then
        scrollList:SetPosition(0, 0)
    else
        scrollList:SetPosition(-20, 0)
    end

    scrollList:Scroll(scrollViewOffset, true)

    return scrollList
end

createOptionWidgets = function(options, markDirty)
    local optionWidgets = {}

    local i = 1
    local labelWidth = 225

    while i <= #options do
        if options[i] then
            local spinOptions = {}
            local spinOptionsHover = {}
            local idx = i
            for _, v in ipairs(options[idx].options) do
                table.insert(spinOptions, { text = v.description, data = v.data })
                spinOptionsHover[v.data] = v.hover
            end
            
            local opt = Widget("option"..idx)

            -- spinner
            
            local spinnerWidth = 170
            local spinnerHeight = 40
            opt.spinner = opt:AddChild(
                Spinner(
                    spinOptions,
                    spinnerWidth,
                    nil,
                    { font = NEWFONT, size = 25 },
                    nil,
                    nil,
                    nil,
                    true,
                    100,
                    nil
                )
            )
            opt.spinner:SetTextColour(0, 0, 0, 1)
            local defaultValue = options[idx].value
            if defaultValue == nil then defaultValue = options[idx].default end
            
            opt.spinner.OnChanged = function(_, data)
                options[idx].value = data
                opt.spinner:SetHoverText(spinOptionsHover[data] or "")
                markDirty()
            end
            opt.spinner:SetSelected(defaultValue)
            opt.spinner:SetHoverText(spinOptionsHover[defaultValue] or "")
            opt.spinner:SetPosition(325, 0, 0)

            -- label

            local label = opt.spinner:AddChild(
                Text(
                    NEWFONT,
                    25,
                    (
                        options[idx].label or
                        options[idx].name or
                        STRINGS.UI.MODSSCREEN.UNKNOWN_MOD_CONFIG_SETTING
                    ) .. ":"
                )
            )
            label:SetColour(0, 0, 0, 1)
            label:SetPosition(-labelWidth / 2 - 90, 0, 0)
            label:SetRegionSize(labelWidth, 50)
            label:SetHAlign(ANCHOR_RIGHT)
            label:SetHoverText(options[idx].hover or "")
            if TheInput:ControllerAttached() then
                opt:SetHoverText(options[idx].hover or "")
            end

            opt.spinner.OnGainFocus = function(self)
                Spinner._base.OnGainFocus(self)
                opt.spinner:UpdateBG()
            end
            opt.focus_forward = opt.spinner

            opt.id = idx
            
            table.insert(optionWidgets, opt)
        end
        i = i + 1
    end

    return optionWidgets
end

--

return OptionsScreen
