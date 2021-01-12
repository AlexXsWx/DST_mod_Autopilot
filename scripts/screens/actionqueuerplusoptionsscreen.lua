local Screen         = require "widgets/screen"
local Image = require "widgets/image"
local Text           = require "widgets/text"
-- local Spinner        = require "widgets/spinner"
local Widget         = require "widgets/widget"
local TEMPLATES = require "widgets/redux/templates"
-- local ScrollableList = require "widgets/scrollablelist"

local createScrollableWindow = require "actionQueuerPlus/ui/createScrollableWindow"

-- forward declaration --
local OptionsScreen_Apply
local getModOptions
local collectSettings
local createDescription
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

    local uiParams = {}
    uiParams.labelWidth = 300
    uiParams.spinnerWidth = 225
    uiParams.itemWidth = uiParams.labelWidth + uiParams.spinnerWidth + 30
    uiParams.itemHeight = 40

    local window = createScrollableWindow({
        parent = self,
        title = (
            KnownModIndex:GetModFancyName(modname)
            -- FIXME
            -- .. " " ..
            -- STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX
        ),
        itemWidth = uiParams.itemWidth,
        onApply  = function() OptionsScreen_Apply(self) end,
        onCancel = function() self:Close() end,
    })

    local description = createDescription(window.header, uiParams)

    self._optionsScrollList = createOptionsScrollList(
        window.dialog,
        self._options,
        description,
        uiParams,
        scrollViewOffset,
        markDirty
    )

    if TheInput:ControllerAttached() then
        window.dialog.actions:Hide()
    end

    self.default_focus = self._optionsScrollList
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
        -- self._optionsScrollList.view_offset,
        -- FIXME
        self._optionsScrollList.current_scroll_pos,
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

createDescription = function(parent, uiParams)

    local optionDescription = parent:AddChild(Text(CHATFONT, 22))
    optionDescription:SetColour(UICOLOURS.GOLD_UNIMPORTANT)
    optionDescription:SetPosition(0, -48)
    optionDescription:SetRegionSize(uiParams.itemWidth + 30, 50)
    -- stop text from jumping around as we scroll
    optionDescription:SetVAlign(ANCHOR_TOP)
    optionDescription:EnableWordWrap(true)

    local valueDescription = parent:AddChild(Text(CHATFONT, 22))
    valueDescription:SetColour(UICOLOURS.GOLD)
    valueDescription:SetPosition(0, -85)
    valueDescription:SetRegionSize(uiParams.itemWidth + 30, 25)

    return {
        optionDescription = optionDescription,
        valueDescription  = valueDescription,
    }

end

createOptionsScrollList = function(parent, options, description, uiParams, scrollViewOffset, markDirty)
    local optionsPanel = parent:InsertWidget(Widget("optionspanel"))
    optionsPanel:SetPosition(0, -60)

    local scrollList = nil

    local optionWidgets = createOptionWidgets(options)

    local function ScrollWidgetsCtor(context, idx)
        local widget = Widget("option"..idx)
        widget.bg = widget:AddChild(
            TEMPLATES.ListItemBackground(uiParams.itemWidth, uiParams.itemHeight)
        )
        widget.opt = widget:AddChild(
            TEMPLATES.LabelSpinner(
                "", {}, uiParams.labelWidth, uiParams.spinnerWidth, uiParams.itemHeight
            )
        )

        widget.opt.spinner:EnablePendingModificationBackground()

        widget.ApplyDescription = function(_)
            local option = widget.opt.data and widget.opt.data.option.hover or ""
            local value = (
                widget.opt.data and
                widget.opt.data.spin_options_hover[widget.opt.data.selected_value] or
                ""
            )
            description.optionDescription:SetString(option)
            description.valueDescription:SetString(value)
        end
        
        widget:SetOnGainFocus(function(_)
            scrollList:OnWidgetFocus(widget)
            widget:ApplyDescription()
        end)

        widget.real_index = idx
        widget.opt.spinner.OnChanged =
            function( _, data )
                options[widget.real_index].value = data
                widget.opt.data.selected_value = data
                widget.opt.spinner:SetHasModification(
                    widget.opt.data.selected_value ~= widget.opt.data.initial_value
                )
                widget:ApplyDescription()
                markDirty()
            end

        widget.focus_forward = widget.opt
        
        return widget
    end

    local function ApplyDataToWidget(context, widget, data, idx)
        widget.opt.data = data
        if data then
            widget.real_index = idx

            widget.opt:Show()
            widget.opt.spinner:SetOptions(data.spin_options)

            if data.is_header then
                widget.bg:Hide()
                widget.opt.spinner:Hide()
                widget.opt.label:SetSize(30)
            else
                widget.bg:Show()
                widget.opt.spinner:Show()
                widget.opt.label:SetSize(25) -- same as LabelSpinner's default.
            end
            
            widget.opt.spinner:SetSelected(data.selected_value)

            local label = (
                data.option.label or
                data.option.name or
                STRINGS.UI.MODSSCREEN.UNKNOWN_MOD_CONFIG_SETTING
            )
            if not data.is_header then
                label =  label .. ":"
            end
            widget.opt.label:SetString(label)

            widget.opt.spinner:SetHasModification(
                widget.opt.data.selected_value ~= widget.opt.data.initial_value
            )

            if widget.focus then
                widget:ApplyDescription()
            end
        else
            widget.opt:Hide()
            widget.bg:Hide()
        end
    end

    scrollList = optionsPanel:AddChild(TEMPLATES.ScrollingGrid(
        optionWidgets,
        {
            scroll_context = {
            },
            widget_width  = uiParams.itemWidth,
            widget_height = uiParams.itemHeight,
            num_visible_rows = 11,
            num_columns = 1,
            item_ctor_fn = ScrollWidgetsCtor,
            apply_fn = ApplyDataToWidget,
            scrollbar_offset = 20,
            scrollbar_height_offset = -60
        }
    ))
    scrollList:SetPosition(0, -6)

    -- Top border of the scroll list.
    local horizontalLine = optionsPanel:AddChild(
        Image("images/global_redux.xml", "item_divider.tex")
    )
    horizontalLine:SetPosition(0, scrollList.visible_rows / 2 * uiParams.itemHeight)
    horizontalLine:SetSize(uiParams.itemWidth + 30, 5)

    -- local scrollList = optionsPanel:AddChild(
    --     ScrollableList({}, 450, 350, 40, 10)
    -- )

    -- scrollList:SetList(optionWidgets)
    -- if scrollList.scroll_bar_line:IsVisible() then
    --     scrollList:SetPosition(0, 0)
    -- else
    --     scrollList:SetPosition(-20, 0)
    -- end

    -- scrollList:Scroll(scrollViewOffset, true)


    -- Skip animation
    -- scrollList.current_scroll_pos = scrollViewOffset
    -- scrollList:Scroll(scrollViewOffset)
    scrollList:ScrollToDataIndex(scrollViewOffset)

    return scrollList
end

createOptionWidgets = function(options)
    local optionWidgets = {}

    -- local i = 1
    -- local labelWidth = 225

    -- while i <= #options do
    --     if options[i] then
    --         local spinOptions = {}
    --         local spinOptionsHover = {}
    --         local idx = i
    --         for _, v in ipairs(options[idx].options) do
    --             table.insert(spinOptions, { text = v.description, data = v.data })
    --             spinOptionsHover[v.data] = v.hover
    --         end
            
    --         local opt = Widget("option"..idx)

    --         -- spinner
            
    --         local spinnerWidth = 170
    --         local spinnerHeight = 40
    --         opt.spinner = opt:AddChild(
    --             Spinner(
    --                 spinOptions,
    --                 spinnerWidth,
    --                 nil,
    --                 { font = NEWFONT, size = 25 },
    --                 nil,
    --                 nil,
    --                 nil,
    --                 true,
    --                 100,
    --                 nil
    --             )
    --         )
    --         opt.spinner:SetTextColour(0, 0, 0, 1)
    --         local defaultValue = options[idx].value
    --         if defaultValue == nil then defaultValue = options[idx].default end
            
    --         opt.spinner.OnChanged = function(_, data)
    --             options[idx].value = data
    --             opt.spinner:SetHoverText(spinOptionsHover[data] or "")
    --             markDirty()
    --         end
    --         opt.spinner:SetSelected(defaultValue)
    --         opt.spinner:SetHoverText(spinOptionsHover[defaultValue] or "")
    --         opt.spinner:SetPosition(325, 0, 0)

    --         -- label

    --         local label = opt.spinner:AddChild(
    --             Text(
    --                 NEWFONT,
    --                 25,
    --                 (
    --                     options[idx].label or
    --                     options[idx].name or
    --                     STRINGS.UI.MODSSCREEN.UNKNOWN_MOD_CONFIG_SETTING
    --                 ) .. ":"
    --             )
    --         )
    --         label:SetColour(0, 0, 0, 1)
    --         label:SetPosition(-labelWidth / 2 - 90, 0, 0)
    --         label:SetRegionSize(labelWidth, 50)
    --         label:SetHAlign(ANCHOR_RIGHT)
    --         label:SetHoverText(options[idx].hover or "")
    --         if TheInput:ControllerAttached() then
    --             opt:SetHoverText(options[idx].hover or "")
    --         end

    --         opt.spinner.OnGainFocus = function(self)
    --             Spinner._base.OnGainFocus(self)
    --             opt.spinner:UpdateBG()
    --         end
    --         opt.focus_forward = opt.spinner

    --         opt.id = idx
            
    --         table.insert(optionWidgets, opt)
    --     end
    --     i = i + 1
    -- end

    for idx, option_item in ipairs(options) do
        local spin_options = {}
        local spin_options_hover = {}
        for _,v in ipairs(option_item.options) do
            table.insert(spin_options, { text = v.description, data = v.data })
            spin_options_hover[v.data] = v.hover
        end
        local initial_value = option_item.value
        if initial_value == nil then
            initial_value = option_item.default
        end
        local data = {
            is_header = #spin_options == 1 and spin_options[1].text:len() == 0,
            option = option_item,
            initial_value = initial_value,
            selected_value = initial_value,
            spin_options = spin_options,
            spin_options_hover = spin_options_hover,
        }

        table.insert(optionWidgets, data)
    end

    return optionWidgets
end

--

return OptionsScreen
