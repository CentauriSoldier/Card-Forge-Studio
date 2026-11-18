-- Manual appearance is game-owned. Empty properties inherit the base presentation.
return {
    Version = 1,
    BaseCSS = "Styles/Appearance Base.css",
    Properties = {
        Container = {frameImage = "Images/Appearance/Defaults/Panel.svg", frameSlice = "12 fill", frameWidth = "12px"},
        Banner = {background = "#202830", image = "Images/Appearance/Defaults/Banner.svg", imageSize = "100% 100%", padding = "1.5rem", minHeight = "8rem"},
    },
};
