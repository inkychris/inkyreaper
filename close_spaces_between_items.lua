local label = "Close Spaces Between Items"

MediaItem = {}
MediaItem.__index = MediaItem
function MediaItem:Create(mediaItem)
    local this = {}
    this.mediaItem = mediaItem
    this.track = reaper.GetMediaItem_Track(this.mediaItem)
    this.index = reaper.GetMediaItemInfo_Value(mediaItem, "IP_ITEMNUMBER")
    this.takeCount = reaper.CountTakes(this.mediaItem)    
    setmetatable(this, MediaItem)
    return this
end

function MediaItem:IsSelected()
    return reaper.IsMediaItemSelected(self.mediaItem)
end

function MediaItem:GetPreviousItem()
    if self.index >= 1 then
        return MediaItem:Create(reaper.GetTrackMediaItem(self.track, self.index - 1))
    end
    return nil
end

function MediaItem:GetFollowingItem()
    if self.index <= reaper.CountTrackMediaItems(self.track) - 2 then
        return MediaItem:Create(reaper.GetTrackMediaItem(self.track, self.index + 1))
    end
    return nil
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

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local selectedItemCount = reaper.CountSelectedMediaItems(0)
for i = 0, selectedItemCount - 1, 1 do
    local item = MediaItem:Create(reaper.GetSelectedMediaItem(0, i))
    local previousItem = item:GetPreviousItem()

    if previousItem and previousItem:IsSelected() then
        item:MoveStartPosition(previousItem:GetEndPosition())
    end
end

reaper.PreventUIRefresh(-1)
reaper.UpdateTimeline()
reaper.Undo_EndBlock(label, 0)
