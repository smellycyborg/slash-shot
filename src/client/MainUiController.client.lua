local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Guis = ReplicatedStorage:WaitForChild("Guis")

local Roact = require(Packages:WaitForChild("roact"))
local RoactTemplate = require(Packages:WaitForChild("roact-template"))

local SideButtons = RoactTemplate.fromInstance(Roact, Guis:WaitForChild("SideButtons"))
local Badges = RoactTemplate.fromInstance(Roact, Guis:WaitForChild("Badges"))
local Combos = RoactTemplate.fromInstance(Roact, Guis:WaitForChild("Combos"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentScreen = "NONE"

local function _setCurrentScreen(name)
    currentScreen = currentScreen == name and "NONE" or name

    updateScreens()

    return currentScreen
end

local function sideButtons(props)
    local screen = props.screen

    return Roact.createElement("ScreenGui", {
        ResetOnSpawn = false,
    }, {
        Frame = Roact.createElement("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(10, 0),
            Size = UDim2.fromScale(0.2, 0.575),
            SizeConstraint = Enum.SizeConstraint.RelativeXX,
        }, {
            UISizeConstraint = Roact.createElement("UISizeConstraint", {
                MaxSize = Vector2.new(200, 600),
            }),

            SideButtons = Roact.createElement(SideButtons, {
                BadgesButton = {
                    [Roact.Event.Activated] = function()
                        _setCurrentScreen("Badges")
                    end,
                },
                CombosButton = {
                    [Roact.Event.Activated] = function()
                        _setCurrentScreen("Combos")
                    end,
                },
                CatalogButton = {
                    [Roact.Event.Activated] = function()
                        _setCurrentScreen("Catalog")
                    end,
                }
            })
        })
    })
end

local function screens(props)
    local screen = props.screen

    return Roact.createElement("ScreenGui", {
        ResetOnSpawn = false,
    }, {
        Badges = Roact.createElement(Badges, {
            [RoactTemplate.Root] = {
                Visible = screen == "Badges",
            }
        }),
        Combos = Roact.createElement(Combos, {
            [RoactTemplate.Root] = {
                Visible = screen == "Combos",
            }
        })
    })
end

local sideButtonsHandle = Roact.mount(Roact.createElement(sideButtons, {
    screen = currentScreen,
}), playerGui, "SideButtons")

local screensHandle = Roact.mount(Roact.createElement(screens, {
    screen = currentScreen,
}), playerGui, "Screens")

function updateScreens()
    Roact.update(screensHandle, Roact.createElement(screens, {
        screen = currentScreen,
    }), playerGui, "Screens")
end