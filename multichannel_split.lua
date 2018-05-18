local label = "Multichannel Split"

function SetMediaItemMonoChannel(mediaItem, channel)
    local itemTake = reaper.GetActiveTake(mediaItem)
    reaper.SetMediaItemTakeInfo_Value(itemTake, "I_CHANMODE", 2 + channel)
end

local function MaxProjectGroupID()
    local mediaItemCount = reaper.CountMediaItems(0)
    local MaxGroupId = 0
    for i = 0, mediaItemCount - 1 do
        local item = reaper.GetMediaItem(0, i)
        local itemGroupId = reaper.GetMediaItemInfo_Value(item, "I_GROUPID")
        if itemGroupId > MaxGroupId then
            MaxGroupId = itemGroupId
        end
    end
    return MaxGroupId
end

Clip = {}
Clip.__index = Clip
function Clip:Create(selectionIndex)
    local this = {}
    this.mediaItem = reaper.GetSelectedMediaItem(0, selectionIndex)
    _, this.stateChunk = reaper.GetItemStateChunk(this.mediaItem , "", false)
    this.activeTake = reaper.GetActiveTake(this.mediaItem)
    this.mediaSource = reaper.GetMediaItemTake_Source(this.activeTake)
    this.channelCount = reaper.GetMediaSourceNumChannels(this.mediaSource)
    this.track = reaper.GetMediaItem_Track(this.mediaItem)
    this.trackIndex = reaper.GetMediaTrackInfo_Value(this.track, "IP_TRACKNUMBER") - 1
    this.createNewTracks = true
    this.duplicates = {}
    setmetatable(this, Clip)
    return this
end

function Clip:GetTargetTrack(channelNumber)
    return reaper.GetTrack(0, self.trackIndex + channelNumber)
end

function Clip:DuplicateMediaItemToTrack(targetTrackIndex)
    local targetTrack = reaper.GetTrack(0, targetTrackIndex)
    local originalChannelCount = reaper.GetMediaTrackInfo_Value(targetTrack, "I_NCHAN")
    local duplicateItem = reaper.AddMediaItemToTrack(targetTrack)
    reaper.SetItemStateChunk(duplicateItem, self.stateChunk, true)
    reaper.SetMediaTrackInfo_Value(targetTrack, "I_NCHAN", originalChannelCount)
    return duplicateItem
end

function Clip:CreateNewTargetTracks()
    for channel = 1, self.channelCount, 1 do
        reaper.InsertTrackAtIndex(self.trackIndex + channel, true)
    end
end

function Clip:CreateMissingTargetTracks()
    local missingTrackCount = self.channelCount - reaper.CountTracks(0) + (self.trackIndex + 1)
    for channel = self.channelCount - missingTrackCount + 1, self.channelCount, 1 do
        reaper.InsertTrackAtIndex(self.trackIndex + channel, true)
    end
end

function Clip:SplitToSubsequentTracks()
    for channel = 1, self.channelCount, 1 do
        local dupItem = self:DuplicateMediaItemToTrack(self.trackIndex + channel)
        SetMediaItemMonoChannel(dupItem, channel)
        table.insert(self.duplicates, dupItem)
    end
end

function Clip:GroupDuplicates()
    local newGroupId = MaxProjectGroupID() + 1
    for dup = 1, self.channelCount, 1 do
        reaper.SetMediaItemInfo_Value(self.duplicates[dup], "I_GROUPID", newGroupId)
    end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local targetMode = reaper.ShowMessageBox("Create new tracks for each channel? Alternatively just creates new tracks as required.", label, 3)

if targetMode == 2 then return end

local itemCount = reaper.CountSelectedMediaItems(0)
for i = 0, itemCount - 1, 1 do
    local clip =  Clip:Create(i)
    if targetMode == 6 then
        clip:CreateNewTargetTracks()
    else
        clip:CreateMissingTargetTracks()
    end
    clip:SplitToSubsequentTracks()
    clip:GroupDuplicates()
end

reaper.PreventUIRefresh(-1)
reaper.UpdateTimeline()
reaper.Undo_EndBlock(label, 0)
