local function RoundUpToEven(number)
    if number % 2 == 0 then
        return number
    end
    return number + 1
end

Track = {}
Track.__index = Track
function Track:Create(trackIndex)
    local this = {}
    this.mediaTrack = reaper.GetTrack(0, trackIndex)
    this.mediaItemCount = reaper.CountTrackMediaItems(this.mediaTrack)
    setmetatable(this, Track)
    return this
end

function Track:GetMediaItemChannelCount(itemIndex)
    local item = reaper.GetTrackMediaItem(self.mediaTrack, itemIndex)
    local itemTake = reaper.GetActiveTake(item)
    local chanmode = reaper.GetMediaItemTakeInfo_Value(itemTake, "I_CHANMODE")
    if chanmode >= 2 then -- 0: Normal mode, 1: reverse mode, 2+ mono
        return 1
    end
    local itemSource = reaper.GetMediaItemTake_Source(itemTake)
    return reaper.GetMediaSourceNumChannels(itemSource)
end

function Track:GetMaxChannelCount()
    local maxChannelCount = 2
    for i = 0, self.mediaItemCount - 1, 1 do
        local itemChannelCount = self:GetMediaItemChannelCount(i)
        if itemChannelCount > maxChannelCount then
            maxChannelCount = itemChannelCount
        end
    end
    return maxChannelCount
end

function Track:ResetChannelCount()
    local channelCount = RoundUpToEven(self:GetMaxChannelCount())
    reaper.SetMediaTrackInfo_Value(self.mediaTrack, "I_NCHAN", channelCount)
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local trackCount = reaper.CountTracks(0)
for i = 0, trackCount - 1, 1 do
    local track = Track:Create(i)
    track:ResetChannelCount()
end

reaper.PreventUIRefresh(-1)
reaper.UpdateTimeline()
reaper.Undo_EndBlock("Reset track channel counts", 0)
