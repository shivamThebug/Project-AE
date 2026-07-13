hl.config({
    general = {
        resize_on_border      = true,
        hover_icon_on_border  = true,
        gaps_in  = 4,
        gaps_out = 12,

        border_size = 2,

        col = {
            active_border = { 
                colors = { "0x80FFFFFF", "0x40FFFFFF" }, 
                angle = 160 
            },
            inactive_border = "0x30FFFFFF",
        },

        allow_tearing = false,
        layout        = "dwindle",
    },

    decoration = {
        rounding       = 16,
        rounding_power = 3.2,

        active_opacity   = 0.94,
        inactive_opacity = 0.85,

        shadow = {
            enabled      = true,
            range        = 26,
            render_power = 4,
            color        = "0x50000000",
        },

        blur = {
            enabled           = true,
            size              = 10,
            passes            = 4,
            vibrancy          = 0.1,
            vibrancy_darkness = 0.05,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.layer_rule({
    match        = { namespace = "rofi" },
    blur         = true,
    ignore_alpha = 0.05,
    xray         = true,
})

hl.curve("smoothEase",     { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1 } } })
hl.curve("softOut",        { type = "bezier", points = { { 0.16, 1 },   { 0.3, 1 } } })
hl.curve("elegantOut",     { type = "bezier", points = { { 0.4, 0 },    { 0.2, 1 } } })
hl.curve("featherOut",     { type = "bezier", points = { { 0.11, 0 },   { 0.5, 0 } } })
hl.curve("gradientSpin",   { type = "bezier", points = { { 0.65, 0 },   { 0.35, 1 } } })
hl.curve("workspaceGlide", { type = "bezier", points = { { 0.22, 1 },   { 0.36, 1 } } })

hl.curve("bouncySpring",    { type = "spring", mass = 1.3, stiffness = 105, dampening = 8  })
hl.curve("popupSpring",     { type = "spring", mass = 0.8, stiffness = 120, dampening = 14 })
hl.curve("workspaceSpring", { type = "spring", mass = 1.1, stiffness = 100, dampening = 16 })

hl.animation({
    leaf    = "global",
    enabled = true,
    speed   = 3.4,
    bezier  = "smoothEase",
})

hl.animation({
    leaf    = "windows",
    enabled = true,
    speed   = 3.0,
    bezier  = "softOut",
})

hl.animation({
    leaf    = "border",
    enabled = true,
    speed   = 2.8,
    bezier  = "smoothEase",
})

hl.animation({
    leaf    = "borderangle",
    enabled = true,
    speed   = 6,
    bezier  = "gradientSpin",
    style   = "once",
})

hl.animation({
    leaf    = "windowsIn",
    enabled = true,
    speed   = 3.8,
    spring  = "bouncySpring",
    style   = "popin 68%",
})

hl.animation({
    leaf    = "windowsOut",
    enabled = true,
    speed   = 2.2,
    bezier  = "elegantOut",
    style   = "popin 85%",
})

hl.animation({
    leaf    = "windowsMove",
    enabled = true,
    speed   = 4.5,
    bezier  = "smoothEase",
})

hl.animation({
    leaf    = "fade",
    enabled = true,
    speed   = 2.8,
    bezier  = "softOut",
})

hl.animation({
    leaf    = "fadeIn",
    enabled = true,
    speed   = 2.4,
    bezier  = "softOut",
})

hl.animation({
    leaf    = "fadeOut",
    enabled = true,
    speed   = 2.0,
    bezier  = "featherOut",
})

hl.animation({
    leaf    = "layers",
    enabled = true,
    speed   = 1.8,
    bezier  = "softOut",
})

hl.animation({
    leaf    = "layersIn",
    enabled = true,
    speed   = 3.2,
    spring  = "popupSpring",
    style   = "popin 75%",
})

hl.animation({
    leaf    = "layersOut",
    enabled = true,
    speed   = 2.0,
    bezier  = "elegantOut",
    style   = "fade",
})

hl.animation({
    leaf    = "workspaces",
    enabled = true,
    speed   = 3.6,
    spring  = "workspaceSpring",
    style   = "slide",
})

hl.animation({
    leaf    = "workspacesIn",
    enabled = true,
    speed   = 3.8,
    spring  = "workspaceSpring",
    style   = "slide2",
})

hl.animation({
    leaf    = "workspacesOut",
    enabled = true,
    speed   = 3.4,
    bezier  = "elegantOut",
    style   = "slide",
})

hl.animation({
    leaf    = "specialWorkspace",
    enabled = true,
    speed   = 3.6,
    bezier  = "workspaceGlide",
    style   = "slidevert",
})

hl.animation({
    leaf    = "zoomFactor",
    enabled = true,
    speed   = 5,
    bezier  = "elegantOut",
})