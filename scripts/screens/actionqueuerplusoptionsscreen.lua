local Screen         = require "widgets/screen"
local Menu           = require "widgets/menu"
local Text           = require "widgets/text"
local Image          = require "widgets/image"
local Spinner        = require "widgets/spinner"
local Widget         = require "widgets/widget"
local TEMPLATES      = require "widgets/templates"
local ScrollableList = require "widgets/scrollablelist"

local ActionQueuerPlusOptionsScreen = Class(Screen, function(self, modname, scrollViewOffset, callback)
    Screen._ctor(self, "ActionQueuerPlusOptionsScreen")

    self._callback = callback
    self.modname = modname
    local config = KnownModIndex:LoadModConfigurationOptions(
        modname,
        true -- client_config
    )

    -- self.options = {
    --     {
    --         name = "name a",
    --         label = "label a",
    --         options = {
    --             { data = "a", description = "a" },
    --             { data = "b", description = "b" },
    --             { data = "c", description = "c" }
    --         },
    --         default = "c",
    --         value = "b",
    --         hover = ""
    --     }
    -- }

    self.options = {}
    
    if config and type(config) == "table" then
        for i,v in ipairs(config) do
            -- Only show the option if it matches our format exactly
            if v.name and v.options and (v.saved ~= nil or v.default ~= nil) then
                local _value = v.saved
                if _value == nil then _value = v.default end
                table.insert(self.options, {name = v.name, label = v.label, options = v.options, default = v.default, value = _value, hover = v.hover})
            end
        end
    end

    -- self.active = true
    -- SetPause(true, "pause")

    -- self.black = self:AddChild(
    --     Image("images/global.xml", "square.tex")
    -- )
    -- self.black:SetVRegPoint(ANCHOR_MIDDLE)
    -- self.black:SetHRegPoint(ANCHOR_MIDDLE)
    -- self.black:SetVAnchor(ANCHOR_MIDDLE)
    -- self.black:SetHAnchor(ANCHOR_MIDDLE)
    -- self.black:SetScaleMode(SCALEMODE_FILLSCREEN)
    -- self.black:SetTint(0, 0, 0, 0.75)

    self.root = self:AddChild(Widget("ROOT"))
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetPosition(0, 0, 0)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)

    self.shield = self.root:AddChild(TEMPLATES.CurlyWindow(40, 365, 1, 1, 67, -41))
    self.shield.fill = self.root:AddChild(
        Image("images/fepanel_fills.xml", "panel_fill_tall.tex")
    )
    self.shield.fill:SetScale(0.64, -0.57)
    self.shield.fill:SetPosition(8, 12)
    self.shield:SetPosition(0, 0, 0)

    local title_max_w = 420
    local title_max_chars = 70
    local title = self.root:AddChild(
        Text(BUTTONFONT, 45, " "..STRINGS.UI.MODSSCREEN.CONFIGSCREENTITLESUFFIX)
    )
    local title_suffix_w = title:GetRegionSize()
    title:SetPosition(10, 190)
    title:SetColour(0, 0, 0, 1)
    if title_suffix_w < title_max_w then
        title:SetTruncatedString(
            "Test",
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

    self.optionspanel = self.root:AddChild(Widget("optionspanel"))  
    self.optionspanel:SetPosition(0, -20)

    self.dirty = false

    self.options_scroll_list = self.optionspanel:AddChild(
        ScrollableList({}, 450, 350, 40, 10)
    )

    self.optionwidgets = {}

    local i = 1
    local label_width = 225

    while i <= #self.options do
        if self.options[i] then
            local spin_options = {} --{{text="default"..tostring(idx), data="default"},{text="2", data="2"}, }
            local spin_options_hover = {}
            local idx = i
            for _,v in ipairs(self.options[idx].options) do
                table.insert(spin_options, {text=v.description, data=v.data})
                spin_options_hover[v.data] = v.hover
            end
            
            local opt = Widget("option"..idx)
            
            local spinner_height = 40
            local spinner_width = 170
            opt.spinner = opt:AddChild(Spinner( spin_options, spinner_width, nil, {font=NEWFONT, size=25}, nil, nil, nil, true, 100, nil))
            opt.spinner:SetTextColour(0,0,0,1)
            local default_value = self.options[idx].value
            if default_value == nil then default_value = self.options[idx].default end
            
            opt.spinner.OnChanged =
                function( _, data )
                    self.options[idx].value = data
                    opt.spinner:SetHoverText( spin_options_hover[data] or "" )
                    self:MakeDirty()
                end
            opt.spinner:SetSelected(default_value)
            opt.spinner:SetHoverText( spin_options_hover[default_value] or "" )
            opt.spinner:SetPosition( 325, 0, 0 )

            local label = opt.spinner:AddChild( Text( NEWFONT, 25, (self.options[idx].label or self.options[idx].name) .. ":" or STRINGS.UI.MODSSCREEN.UNKNOWN_MOD_CONFIG_SETTING..":" ) )
            label:SetColour( 0, 0, 0, 1 )
            label:SetPosition( -label_width/2 - 90, 0, 0 )
            label:SetRegionSize( label_width, 50 )
            label:SetHAlign( ANCHOR_RIGHT )
            label:SetHoverText( self.options[idx].hover or "" )
            if TheInput:ControllerAttached() then
                opt:SetHoverText( self.options[idx].hover or "" )
            end

            opt.spinner.OnGainFocus = function()
                Spinner._base.OnGainFocus(self)
                opt.spinner:UpdateBG()
            end
            opt.focus_forward = opt.spinner

            opt.id = idx
            
            table.insert(self.optionwidgets, opt)
            i = i + 1
        end
    end

    self.menu = self.root:AddChild(Menu(nil, 0, true))
    self.applybutton = self.menu:AddItem(
        STRINGS.UI.MODSSCREEN.APPLY,
        function() self:Apply() end,
        Vector3(165, -230, 0),
        "large"
    )
    self.cancelbutton = self.menu:AddItem(
        STRINGS.UI.MODSSCREEN.BACK,
        function() self:Cancel() end,
        Vector3(-155, -230, 0)
    )
    self.applybutton:SetScale(.7)
    self.cancelbutton:SetScale(.7)
    self.menu:SetPosition(5,0)

    -- self.default_focus = self.optionwidgets[1]
    -- self:HookupFocusMoves()

    self.options_scroll_list:SetList(self.optionwidgets)
    if self.options_scroll_list.scroll_bar_line:IsVisible() then
        self.options_scroll_list:SetPosition(0, 0)
    else
        self.options_scroll_list:SetPosition(-20, 0)
    end

    self.options_scroll_list:Scroll(scrollViewOffset, true)

end)

function ActionQueuerPlusOptionsScreen:CollectSettings()
    local settings = nil
    for i,v in pairs(self.options) do
        if not settings then settings = {} end
        table.insert(settings, {name=v.name, label = v.label, options=v.options, default=v.default, saved=v.value})
    end
    return settings
end

function ActionQueuerPlusOptionsScreen:Apply()
    if not self:IsDirty() then
        self:Close()
        return    
    end

    local settings = self:CollectSettings()
    KnownModIndex:SaveConfigurationOptions(
        function() 
            self:MakeDirty(false)
            self:Close(true)
        end,
        self.modname,
        settings,
        true -- self.client_config
    )
end

function ActionQueuerPlusOptionsScreen:Cancel()
    self:Close()
end

function ActionQueuerPlusOptionsScreen:OnControl(control, down)
    if ActionQueuerPlusOptionsScreen._base.OnControl(self, control, down) then return true end
    
    if not down and (
        control == CONTROL_PAUSE or
        control == CONTROL_CANCEL or
        control == CONTROL_MENU_MISC_3
    ) then
        self:Close()
        return true
    end
end

-- function ActionQueuerPlusOptionsScreen:OnRawKey(key, down)

--     if ActionQueuerPlusOptionsScreen._base.OnRawKey(self, key, down) then return true end
    
--     if key == self.togglekey and not down then
--         -- self.callbacks.ignore()
--         self:Close()
--         return true
--     end
-- end

function ActionQueuerPlusOptionsScreen:Close(optHadEffect)
    self._callback(self.options_scroll_list.view_offset, optHadEffect or false)
    TheFrontEnd:PopScreen() 
    -- SetPause(false)
    -- GetWorld():PushEvent("continuefrompause")
    -- TheFrontEnd:GetSound():PlaySound("dontstarve/HUD/click_move")
end

function ActionQueuerPlusOptionsScreen:MakeDirty(dirty)
    if dirty ~= nil then
        self.dirty = dirty
    else
        self.dirty = true
    end
end

function ActionQueuerPlusOptionsScreen:IsDirty()
    return self.dirty
end

return ActionQueuerPlusOptionsScreen
