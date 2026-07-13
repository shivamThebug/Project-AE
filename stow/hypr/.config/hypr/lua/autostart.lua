local autostart = {}

function autostart.load(terminal)
    hl.on("hyprland.start", function()
        hl.exec_cmd("waybar")
        hl.exec_cmd("waypaper --restore")
    end)
end

return autostart