local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Music = ReplicatedStorage:WaitForChild("Music")

local function playMusic()
    local allMusic = Music:GetChildren()
    if not next(allMusic) then
        task.wait()
        return playMusic()
    end

    if #allMusic == 1 then
        local song = allMusic[1]
        song:Play()
        song.Ended:Connect(playMusic)
    else
        local randomIndex = math.random
        local randomSong = Music:GetChildren()[randomIndex()]
        randomSong:Play()
        randomSong.Ended:Connect(playMusic)
    end
end

playMusic()