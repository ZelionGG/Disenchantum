local _, addon = ...

local Theme = {
    colors = {
        window = { 0.04, 0.04, 0.05, 0.98 },
        titleBar = { 0.05, 0.05, 0.07, 0.98 },
        sidebar = { 0.055, 0.055, 0.06, 0.96 },
        workspace = { 0.05, 0.05, 0.055, 0.96 },
        card = { 0.085, 0.085, 0.095, 0.94 },
        cardSoft = { 0.075, 0.075, 0.085, 0.9 },
        cardInset = { 0.06, 0.06, 0.07, 0.95 },
        input = { 0.045, 0.045, 0.05, 0.98 },
        border = { 0.16, 0.16, 0.22, 0.92 },
        borderSoft = { 0.13, 0.13, 0.18, 0.85 },
        borderMuted = { 0.11, 0.11, 0.14, 0.8 },
        accent = { 0.38, 0.82, 0.88, 1 },
        accentAlt = { 0.78, 0.62, 0.95, 1 },
        accentSoft = { 0.22, 0.48, 0.55, 0.95 },
        accentDim = { 0.12, 0.28, 0.34, 0.92 },
        success = { 0.26, 0.72, 0.44, 1 },
        warning = { 0.9, 0.68, 0.26, 1 },
        danger = { 0.78, 0.29, 0.27, 1 },
        text = { 0.92, 0.93, 0.96, 1 },
        textMuted = { 0.68, 0.70, 0.74, 1 },
        textDim = { 0.5, 0.5, 0.52, 1 },
        disabledButton = { 0.22, 0.22, 0.24, 0.96 },
        disabledButtonBorder = { 0.38, 0.38, 0.4, 0.95 },
        disabledButtonText = { 0.62, 0.62, 0.64, 1 },
    },
}

addon.Theme = Theme

function Theme.UnpackColor(color)
    return color[1], color[2], color[3], color[4] or 1
end

function Theme.ApplyGradient(texture, orientation, fromColor, toColor)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient(
        orientation,
        CreateColor(Theme.UnpackColor(fromColor)),
        CreateColor(Theme.UnpackColor(toColor))
    )
end

function Theme.ApplySurface(frame, background, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true,
        tileSize = 8,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(Theme.UnpackColor(background or Theme.colors.card))
    frame:SetBackdropBorderColor(Theme.UnpackColor(border or Theme.colors.border))
end

function Theme.CreatePanel(parent, background, border)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Theme.ApplySurface(panel, background, border)
    return panel
end

function Theme.SetFontColor(fontString, color)
    fontString:SetTextColor(Theme.UnpackColor(color))
end

function Theme.CreateText(parent, text, variant)
    local fontObject = "GameFontHighlight"
    if variant == "heading" then
        fontObject = "GameFontNormalLarge"
    elseif variant == "label" then
        fontObject = "GameFontHighlightSmall"
    elseif variant == "muted" then
        fontObject = "GameFontDisable"
    end

    local label = parent:CreateFontString(nil, "ARTWORK", fontObject)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(text or "")

    if variant == "heading" then
        Theme.SetFontColor(label, Theme.colors.accent)
    elseif variant == "label" or variant == "muted" then
        Theme.SetFontColor(label, Theme.colors.textMuted)
    else
        Theme.SetFontColor(label, Theme.colors.text)
    end

    return label
end

function Theme.UpdateButtonColors(button)
    local colors = Theme.colors
    local variant = button.variant or "secondary"
    local palette = {
        primary = {
            normal = { bg = colors.accentDim, border = colors.accent, text = colors.text },
            hover = { bg = colors.accentSoft, border = colors.accentAlt, text = colors.text },
            active = { bg = colors.accentSoft, border = colors.accentAlt, text = colors.text },
            disabled = { bg = colors.disabledButton, border = colors.disabledButtonBorder, text = colors.disabledButtonText },
        },
        secondary = {
            normal = { bg = colors.cardInset, border = colors.borderSoft, text = colors.text },
            hover = { bg = colors.cardSoft, border = colors.accentAlt, text = colors.text },
            active = { bg = colors.cardSoft, border = colors.accentAlt, text = colors.text },
            disabled = { bg = colors.cardInset, border = colors.borderMuted, text = colors.textDim },
        },
        danger = {
            normal = { bg = { 0.22, 0.08, 0.08, 0.95 }, border = { 0.42, 0.14, 0.14, 0.95 }, text = colors.text },
            hover = { bg = { 0.32, 0.1, 0.1, 0.95 }, border = colors.danger, text = colors.text },
            active = { bg = { 0.32, 0.1, 0.1, 0.95 }, border = colors.danger, text = colors.text },
            disabled = { bg = colors.cardInset, border = colors.borderMuted, text = colors.textDim },
        },
        subtle = {
            normal = { bg = colors.card, border = colors.borderMuted, text = colors.textMuted },
            hover = { bg = colors.cardSoft, border = colors.borderSoft, text = colors.text },
            active = { bg = colors.cardSoft, border = colors.accentAlt, text = colors.text },
            disabled = { bg = colors.cardInset, border = colors.borderMuted, text = colors.textDim },
        },
    }

    local state = palette[variant] or palette.secondary
    local style
    if button.visualEnabled == false or (button.IsEnabled and not button:IsEnabled()) then
        style = state.disabled
    elseif button.isSelected then
        style = state.active
    elseif button.isHovered or button.holdHover then
        style = state.hover
    else
        style = state.normal
    end

    Theme.ApplySurface(button, style.bg, style.border)
    if button.Label then
        Theme.SetFontColor(button.Label, style.text)
    end
    if button.Title then
        Theme.SetFontColor(button.Title, Theme.colors.text)
    end
    if button.Meta then
        Theme.SetFontColor(button.Meta, button.isSelected and Theme.colors.textMuted or Theme.colors.textDim)
    end
end

function Theme.CreateButton(parent, width, height, text, variant, frameName, extraTemplates)
    local templates = extraTemplates and (extraTemplates .. ", BackdropTemplate") or "BackdropTemplate"
    local button = CreateFrame("Button", frameName, parent, templates)
    button:SetSize(width, height)
    button.variant = variant or "secondary"
    button.isSelected = false
    button.isHovered = false
    button.visualEnabled = true

    button.Label = Theme.CreateText(button, text or "", "body")
    button.Label:SetPoint("CENTER")
    button.Label:SetJustifyH("CENTER")

    button:SetScript("OnEnter", function(self)
        self.isHovered = true
        Theme.UpdateButtonColors(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.isHovered = false
        Theme.UpdateButtonColors(self)
    end)
    local function placeLabel(self, extraY)
        if not self.Label then
            return
        end
        self.Label:SetPoint("CENTER", self.labelOffsetX or 0, (self.labelOffsetY or 0) + extraY)
    end

    button:SetScript("OnMouseDown", function(self)
        placeLabel(self, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        placeLabel(self, 0)
    end)

    function button:SetText(value)
        self.Label:SetText(value or "")
    end

    function button:SetSelected(selected)
        self.isSelected = selected == true
        Theme.UpdateButtonColors(self)
    end

    function button:SetVisualEnabled(enabled)
        enabled = enabled == true
        self.visualEnabled = enabled
        if not InCombatLockdown() then
            self:SetEnabled(enabled)
        end
        self:SetAlpha(1)
        Theme.UpdateButtonColors(self)
    end

    Theme.UpdateButtonColors(button)
    return button
end

function Theme.CreateCheckbox(parent, width, text)
    local checkbox = CreateFrame("Button", nil, parent, "BackdropTemplate")
    checkbox:SetSize(width or 120, 22)
    checkbox.value = false
    checkbox.isHovered = false

    checkbox.box = Theme.CreatePanel(checkbox, Theme.colors.input, Theme.colors.borderSoft)
    checkbox.box:SetSize(16, 16)
    checkbox.box:SetPoint("LEFT", checkbox, "LEFT", 0, 0)

    checkbox.indicator = checkbox.box:CreateTexture(nil, "ARTWORK")
    checkbox.indicator:SetColorTexture(Theme.UnpackColor(Theme.colors.accent))
    checkbox.indicator:SetPoint("TOPLEFT", checkbox.box, "TOPLEFT", 4, -4)
    checkbox.indicator:SetPoint("BOTTOMRIGHT", checkbox.box, "BOTTOMRIGHT", -4, 4)
    checkbox.indicator:Hide()

    checkbox.label = Theme.CreateText(checkbox, text or "", "body")
    checkbox.label:SetPoint("LEFT", checkbox.box, "RIGHT", 8, 0)
    checkbox.label:SetJustifyH("LEFT")

    checkbox.count = Theme.CreateText(checkbox, "", "label")
    checkbox.count:SetPoint("RIGHT", checkbox, "RIGHT", 0, 0)
    checkbox.count:SetWidth(1)
    checkbox.count:SetJustifyH("RIGHT")
    checkbox.label:SetPoint("RIGHT", checkbox.count, "LEFT", -8, 0)
    checkbox.visualEnabled = true

    function checkbox:RefreshVisual()
        local borderColor = Theme.colors.borderSoft
        if self.value then
            borderColor = Theme.colors.accentAlt
        elseif self.isHovered then
            borderColor = Theme.colors.accentAlt
        end

        Theme.ApplySurface(self.box, Theme.colors.input, borderColor)
        self.indicator:SetShown(self.value)
        local labelColor = self.value and Theme.colors.text or Theme.colors.textMuted
        if self.visualEnabled == false then
            labelColor = Theme.colors.textDim
        end
        Theme.SetFontColor(self.label, labelColor)
        Theme.SetFontColor(self.count, Theme.colors.textMuted)
    end

    function checkbox:SetCheckedState(value)
        self.value = value == true
        self:RefreshVisual()
    end

    function checkbox:GetCheckedState()
        return self.value == true
    end

    function checkbox:SetCount(value)
        if value == nil or value == "" then
            self.count:SetText("")
            self.count:SetWidth(1)
            return
        end
        self.count:SetWidth(36)
        self.count:SetText(tostring(value))
    end

    function checkbox:SetVisualEnabled(enabled)
        self.visualEnabled = enabled ~= false
        if enabled == false then
            self:Disable()
            self:SetAlpha(0.5)
        else
            self:Enable()
            self:SetAlpha(1)
        end
        self:RefreshVisual()
    end

    checkbox:SetScript("OnEnter", function(self)
        self.isHovered = true
        self:RefreshVisual()
    end)
    checkbox:SetScript("OnLeave", function(self)
        self.isHovered = false
        self:RefreshVisual()
    end)

    checkbox:RefreshVisual()
    return checkbox
end

function Theme.CreateItemIcon(parent, size)
    size = size or 40
    local wrap = Theme.CreatePanel(parent, { 0.02, 0.02, 0.02, 1 }, Theme.colors.border)
    wrap:SetSize(size + 2, size + 2)

    local icon = wrap:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", wrap, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", wrap, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    wrap.Texture = icon

    wrap.QualityOverlay = wrap:CreateTexture(nil, "OVERLAY")
    wrap.QualityOverlay:SetPoint("TOPLEFT", wrap, "TOPLEFT", -3, 2)
    wrap.QualityOverlay:SetDrawLayer("OVERLAY", 7)
    wrap.QualityOverlay:Hide()

    function wrap:SetIcon(fileID)
        self.Texture:SetTexture(fileID)
    end

    function wrap:SetQuality(quality)
        if quality and C_Item.GetItemQualityColor then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            self:SetBackdropBorderColor(r, g, b, 1)
        else
            self:SetBackdropBorderColor(Theme.UnpackColor(Theme.colors.border))
        end
    end

    function wrap:SetCraftingQuality(atlas)
        if atlas then
            if TextureKitConstants and TextureKitConstants.UseAtlasSize then
                self.QualityOverlay:SetAtlas(atlas, TextureKitConstants.UseAtlasSize)
            else
                self.QualityOverlay:SetAtlas(atlas)
            end
            self.QualityOverlay:Show()
        else
            self.QualityOverlay:Hide()
        end
    end

    return wrap
end

function Theme.CreateCard(parent, width, height)
    local card = Theme.CreatePanel(parent, Theme.colors.card, Theme.colors.borderSoft)
    if width then
        card:SetWidth(width)
    end
    if height then
        card:SetHeight(height)
    end
    return card
end

function Theme.SetCardTone(card, tone)
    local border = Theme.colors.borderSoft
    if tone == "accent" then
        border = Theme.colors.accent
    elseif tone == "success" then
        border = Theme.colors.success
    elseif tone == "warning" then
        border = Theme.colors.warning
    elseif tone == "danger" then
        border = Theme.colors.danger
    elseif tone == "muted" then
        border = Theme.colors.borderMuted
    end

    Theme.ApplySurface(card, Theme.colors.card, border)
end

function Theme.CreateStyledScrollArea(parent, contentWidth)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(contentWidth, 1)
    scrollFrame:SetScrollChild(content)

    local scrollBar = CreateFrame("Frame", nil, parent)
    scrollBar:SetWidth(10)
    scrollBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -8)
    scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 8)
    scrollBar:EnableMouse(true)
    scrollBar:Hide()

    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    Theme.ApplyGradient(track, "VERTICAL", { 0.10, 0.22, 0.28, 0.35 }, { 0.22, 0.14, 0.32, 0.35 })
    track:SetPoint("TOP", scrollBar, "TOP", 0, 0)
    track:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 0)
    track:SetWidth(3)

    local thumb = CreateFrame("Button", nil, scrollBar, "BackdropTemplate")
    Theme.ApplySurface(thumb, Theme.colors.accentDim, Theme.colors.accent)
    thumb:SetWidth(7)
    thumb:SetPoint("TOP", scrollBar, "TOP", 0, 0)
    thumb:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    scrollBar.thumb = thumb

    local function getScrollMetrics()
        local visibleHeight = scrollFrame:GetHeight() or 0
        local contentHeight = content:GetHeight() or 0
        local range = math.max(0, contentHeight - visibleHeight)
        local thumbHeight = 0
        if contentHeight > 0 and visibleHeight > 0 then
            thumbHeight = math.max(28, math.floor((visibleHeight / contentHeight) * visibleHeight))
            thumbHeight = math.min(visibleHeight, thumbHeight)
        end

        local travel = math.max(0, (scrollBar:GetHeight() or 0) - thumbHeight)
        return visibleHeight, contentHeight, range, thumbHeight, travel
    end

    local function positionThumb(scrollValue)
        local _, _, range, thumbHeight, travel = getScrollMetrics()
        thumb:SetHeight(thumbHeight)

        if range <= 0 or travel <= 0 then
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", scrollBar, "TOP", 0, 0)
            return
        end

        local offset = (scrollValue / range) * travel
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", scrollBar, "TOP", 0, -offset)
    end

    local function setScrollValue(scrollValue)
        local _, _, range = getScrollMetrics()
        if scrollValue < 0 then
            scrollValue = 0
        elseif scrollValue > range then
            scrollValue = range
        end

        scrollFrame:SetVerticalScroll(scrollValue)
        positionThumb(scrollValue)
    end

    local function scrollFromCursor()
        local _, _, range, thumbHeight, travel = getScrollMetrics()
        if range <= 0 or travel <= 0 then
            setScrollValue(0)
            return
        end

        local scale = scrollBar:GetEffectiveScale() or 1
        local cursorY = select(2, GetCursorPosition()) / scale
        local top = scrollBar:GetTop() or 0
        local offset = top - cursorY - (thumbHeight * 0.5)

        if offset < 0 then
            offset = 0
        elseif offset > travel then
            offset = travel
        end

        setScrollValue((offset / travel) * range)
    end

    local function updateScrollBar()
        setScrollValue(scrollFrame:GetVerticalScroll() or 0)

        local _, _, range = getScrollMetrics()
        if range <= 1 then
            scrollBar:Hide()
            return
        end

        scrollBar:Show()
    end

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if not scrollBar:IsShown() then
            return
        end

        local step = math.max(28, math.floor((scrollFrame:GetHeight() or 0) * 0.18))
        setScrollValue((scrollFrame:GetVerticalScroll() or 0) - (delta * step))
    end)

    thumb:SetScript("OnMouseDown", function(self)
        self.isDragging = true
        Theme.ApplySurface(self, Theme.colors.accentSoft, Theme.colors.accentAlt)
        self:SetScript("OnUpdate", scrollFromCursor)
        scrollFromCursor()
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
        Theme.ApplySurface(self, Theme.colors.accentDim, Theme.colors.accent)
    end)
    thumb:SetScript("OnHide", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    thumb:SetScript("OnEnter", function(self)
        Theme.ApplySurface(self, Theme.colors.accentSoft, Theme.colors.accentAlt)
    end)
    thumb:SetScript("OnLeave", function(self)
        if self.isDragging then
            Theme.ApplySurface(self, Theme.colors.accentSoft, Theme.colors.accentAlt)
        else
            Theme.ApplySurface(self, Theme.colors.accentDim, Theme.colors.accent)
        end
    end)

    scrollBar:SetScript("OnMouseDown", function()
        scrollFromCursor()
    end)

    scrollFrame:SetScript("OnShow", updateScrollBar)
    scrollFrame:SetScript("OnSizeChanged", updateScrollBar)
    content:SetScript("OnSizeChanged", updateScrollBar)
    scrollBar:SetScript("OnSizeChanged", updateScrollBar)

    scrollFrame.UpdateScrollBar = updateScrollBar
    scrollFrame.ScrollBar = scrollBar
    scrollFrame.ScrollChild = content

    return scrollFrame, content, scrollBar
end
