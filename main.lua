--Classes
local mod = RegisterMod("Sounds Display", 1)
local game = Game()
local SFX = SFXManager()
local font = Font()
local Helper = {}

font:Load("font/luaminioutlined.fnt")

--Constants
local TEXT_X = 60
local TEXT_Y = 52
local LINE_HEIGHT = font:GetLineHeight()
local NUMBERS_WIDTH = font:GetStringWidth("000")
local TEXT_COLOR = KColor(1, 1, 1, 0.3)
local TEXT_COLOR_TITLE = KColor(0.9, 0.9, 1, 0.3)
local TEXT_COLOR_PLAYING = KColor(0, 1, 0, 0.3)
local SOUND_EFFECT_COLOR_FRAMES = 14

local PER_LINE_OFFSET_X = 185

local REVERSE_SOUNDEFFECT = {}
for soundName, soundId in pairs(SoundEffect) do REVERSE_SOUNDEFFECT[soundId] = soundName end

local BROKEN_SOUND_EFFECTS = {
    SoundEffect.SOUND_CHARACTER_SELECT_LEFT,
    SoundEffect.SOUND_CHARACTER_SELECT_RIGHT,
    SoundEffect.SOUND_BOOK_PAGE_TURN_12,
    SoundEffect.SOUND_MENU_SCROLL,
    SoundEffect.SOUND_MENU_NOTE_APPEAR,
    SoundEffect.SOUND_MENU_NOTE_HIDE,
    SoundEffect.SOUND_SPLATTER,
} --Sounds that seem to "keep playing"

local MOUSE_BUTTON_PLAY_SOUND = 0
local MOUSE_BUTTON_CLEAR_SOUND  = 1

local SEPERATOR = " - "

local KEY_TOGGLE = "KEY_L"
local KEY_CLEAR = "KEY_K"
local KEY_MODIFIER = "KEY_LEFT_CONTROL"

--Mod variables
local playedSounds = {}
local renderOrder = {}
local clickedSounds = {}
local isMousePressed, wasToggleKeyPressed
local isEnabled

--Function (callbacks)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    Helper.UpdatePlayingSounds()

    if isEnabled then
        Helper.RenderSoundDisplay()
        Helper.UpdateSoundDisplayClicking()
    end
    Helper.CheckForKeysPressed()
end)

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
    Helper.UpdatePlayingSounds()
    for _, soundId in pairs(BROKEN_SOUND_EFFECTS) do
        SFX:Stop(soundId)
    end
end)

--Functions (helper)
function Helper.UpdatePlayingSounds()
    for soundId in pairs(REVERSE_SOUNDEFFECT) do
        if SFX:IsPlaying(soundId) then
            playedSounds[soundId] = SOUND_EFFECT_COLOR_FRAMES
            Helper.TryAddToRenderOrder(soundId)
        end
    end
end

function Helper.RenderSoundDisplay()
    local lines = Helper.GetLinesAndLinesMaxTextWidth()

    for soundId in pairs(playedSounds) do
        playedSounds[soundId] = playedSounds[soundId] - 1
    end

    for line, sounds in pairs(lines) do
        local soundNum = 0
        for _, soundId in pairs(sounds) do
            local soundDuration = playedSounds[soundId]

            local color = Helper.LerpKColor(TEXT_COLOR_PLAYING, TEXT_COLOR, math.max(0, soundDuration))
            font:DrawString(soundId, TEXT_X + PER_LINE_OFFSET_X * line, TEXT_Y + LINE_HEIGHT * soundNum, color)
            font:DrawString(SEPERATOR .. REVERSE_SOUNDEFFECT[soundId], TEXT_X + NUMBERS_WIDTH + PER_LINE_OFFSET_X * line, TEXT_Y + LINE_HEIGHT * soundNum, color)
            soundNum = soundNum + 1
        end
    end

    font:DrawString("SOUND DISPLAY+", TEXT_X, TEXT_Y - LINE_HEIGHT, TEXT_COLOR_TITLE)
end

function Helper.UpdateSoundDisplayClicking()
    if game:IsPaused() or Options.Fullscreen then return end

    local playSoundButtonPressed = Input.IsMouseBtnPressed(MOUSE_BUTTON_PLAY_SOUND)
    local clearSoundButtonPressed = Input.IsMouseBtnPressed(MOUSE_BUTTON_CLEAR_SOUND)

    if not (playSoundButtonPressed or clearSoundButtonPressed) then
        clickedSounds = {}
        isMousePressed = false
        return
    end

    if isMousePressed then return end

    local scale = Isaac.GetScreenPointScale()

    local maxSoundsPerLine = math.floor((Isaac.GetScreenHeight() - TEXT_Y)/LINE_HEIGHT)

    local mousePosition = Input.GetMousePosition()
    for index, soundId in pairs(renderOrder) do
        local line = math.ceil(index/maxSoundsPerLine) - 1

        local soundName = REVERSE_SOUNDEFFECT[soundId]
        local stringWidth = font:GetStringWidth(soundId .. SEPERATOR .. soundName)

        local isInsideOfXWidth = mousePosition.X >= TEXT_X * scale + PER_LINE_OFFSET_X * line * scale  and mousePosition.X <= TEXT_X * scale + stringWidth * scale + PER_LINE_OFFSET_X * line * scale 
        local isInsideOfYWidth = mousePosition.Y >= TEXT_Y * scale  + LINE_HEIGHT * (index % maxSoundsPerLine - 1) * scale and mousePosition.Y <= TEXT_Y * scale + LINE_HEIGHT * (index % maxSoundsPerLine) * scale

        if isInsideOfXWidth and isInsideOfYWidth then
            if not clickedSounds[soundId] and playSoundButtonPressed then
                if not Input.IsButtonPressed(Keyboard[KEY_MODIFIER], 0) then
                    SFX:Play(soundId)
                else
                    SFX:Stop(soundId)
                end
                clickedSounds[soundId] = true
                break
            else
                table.remove(renderOrder, index)
                SFX:Stop(soundId)
                break
            end
        end
    end

    isMousePressed = true
end

function Helper.CheckForKeysPressed()
    if game:IsPaused() then return end


    local isToggleKeyPressed = Input.IsButtonPressed(Keyboard[KEY_TOGGLE], 0)
    if isToggleKeyPressed and not wasToggleKeyPressed then
        isEnabled = not isEnabled
    end
    wasToggleKeyPressed = isToggleKeyPressed

    if isEnabled and Input.IsButtonPressed(Keyboard[KEY_CLEAR], 0) then
        for soundId in pairs(playedSounds) do SFX:Stop(soundId) end
        if not Input.IsButtonPressed(Keyboard[KEY_MODIFIER], 0) then
            playedSounds, renderOrder, clickedSounds = {}, {}, {}
        end
    end
end

--Functions (helper^2)
function Helper.GetLinesAndLinesMaxTextWidth()
    local lines = {}

    local maxSoundsPerLine = math.floor((Isaac.GetScreenHeight() - TEXT_Y)/LINE_HEIGHT)

    for soundNum, soundId in pairs(renderOrder) do
        local lineNum = math.ceil(soundNum/maxSoundsPerLine) - 1

        if not lines[lineNum] then
            lines[lineNum] = {}
        end

        table.insert(lines[lineNum], soundId)
    end

    return lines
end

function Helper.TryAddToRenderOrder(soundId)
    for _, thisSoundId in pairs(renderOrder) do
        if thisSoundId == soundId then return end
    end

    table.insert(renderOrder, soundId)
end

function Helper.LerpKColor(kcolor1, kcolor2, percent)
    local color1 = Color(kcolor1.Red, kcolor1.Green, kcolor1.Blue, kcolor1.Alpha)
    local color2 = Color(kcolor2.Red, kcolor2.Green, kcolor2.Blue, kcolor2.Alpha)

    local lerpedColor = Color.Lerp(color2, color1, percent/SOUND_EFFECT_COLOR_FRAMES)
    return KColor(lerpedColor.R, lerpedColor.G, lerpedColor.B, lerpedColor.A)
end

for _, soundEffect in pairs(BROKEN_SOUND_EFFECTS) do
    SFX:Stop(soundEffect)
end

print("Sound Display+ loaded. Press", KEY_TOGGLE, "to toggle the display &", KEY_CLEAR, "to clear it. Modifier key is", KEY_MODIFIER)