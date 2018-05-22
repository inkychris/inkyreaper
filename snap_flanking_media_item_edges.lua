local label = "Snap Flanking Media Item Edges"

MediaItem = {}
MediaItem.__index = MediaItem
function MediaItem:Create(mediaItem)
    local this = {}
    this.mediaItem = mediaItem
    this.takeCount = reaper.CountTakes(this.mediaItem)
    setmetatable(this, MediaItem)
    return this
end

function MediaItem:GetStartPosition()
    return reaper.GetMediaItemInfo_Value(self.mediaItem, "D_POSITION")
end

function MediaItem:GetLength()
    return reaper.GetMediaItemInfo_Value(self.mediaItem, "D_LENGTH")
end

function MediaItem:GetEndPosition()
    return self:GetStartPosition() + self:GetLength()
end

function MediaItem:MoveEndPosition(destination)
    local lengthDelta = destination - self:GetEndPosition()
    reaper.SetMediaItemInfo_Value(self.mediaItem, "D_LENGTH", self:GetLength() + lengthDelta)
end

function MediaItem:OffsetTakes(delta)
    for i = 0, self.takeCount - 1, 1 do
        local take = reaper.GetMediaItemTake(self.mediaItem, i)
        local takeOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
        reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", takeOffset - delta)
    end
end

function MediaItem:MoveStartPosition(destination)
    local originalEndPosition = self:GetEndPosition()
    self:OffsetTakes(self:GetStartPosition() - destination)
    reaper.SetMediaItemInfo_Value(self.mediaItem, "D_POSITION", destination)
    self:MoveEndPosition(originalEndPosition)
end

Track = {}
Track.__index = Track
function Track:Create(trackIndex)
    local this = {}
    this.mediaTrack = reaper.GetSelectedTrack(0, trackIndex)
    this.mediaItemCount = reaper.CountTrackMediaItems(this.mediaTrack)
    this.previousItem = nil
    this.nextItem = nil
    setmetatable(this, Track)
    return this
end

function Track:GetMediaItem(itemIndex)
    return MediaItem:Create(reaper.GetTrackMediaItem(self.mediaTrack, itemIndex))
end

function Track:SnapFlankingItemEdgesToPosition(position)
    for i = 0, self.mediaItemCount - 1, 1 do
        local currentItem = self:GetMediaItem(i)

        if position >= currentItem:GetStartPosition() and position <=currentItem:GetEndPosition() then
            return
        end

        if position <= currentItem:GetStartPosition() then
            self.nextItem = currentItem
            break
        end
        self.previousItem = currentItem
    end

    if self.previousItem then
        self.previousItem:MoveEndPosition(position)
    end

    if self.nextItem then
        self.nextItem:MoveStartPosition(position)
    end
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local cursorPosition = reaper.GetCursorPosition(0)
local trackCount = reaper.CountSelectedTracks(0)
for i = 0, trackCount - 1, 1 do
    local track = Track:Create(i)
    track:SnapFlankingItemEdgesToPosition(cursorPosition)
end

reaper.PreventUIRefresh(-1)
reaper.UpdateTimeline()
reaper.Undo_EndBlock(label, 0)
