var plasma = getApiVersion(1);

var layout = {
    "desktops": [
        {
            "applets": [],
            "config": {
                "/": { "formfactor": "0", "immutability": "1" }
            },
            "wallpaperPlugin": "org.kde.image"
        }
    ],
    "panels": [
        {
            "alignment": "left",
            "applets": [
                { "plugin": "org.kde.plasma.kickoff" },
                {
                    "config": {
                        "/Configuration/General": {
                            "launchers": "applications:org.kde.dolphin.desktop,applications:ventos-longes.desktop,applications:google-chrome.desktop,applications:ventos-modojogo.desktop,applications:org.kde.konsole.desktop"
                        }
                    },
                    "plugin": "org.kde.plasma.icontasks"
                },
                { "plugin": "org.kde.plasma.marginsseparator" },
                { "plugin": "org.kde.plasma.systemtray" },
                { "plugin": "org.kde.plasma.digitalclock" },
                { "plugin": "org.kde.plasma.showdesktop" }
            ],
            "config": { "/": { "formfactor": "2", "immutability": "1" } },
            "height": 2,
            "hiding": "normal",
            "location": "bottom",
            "maximumLength": 10000,
            "minimumLength": 10000,
            "offset": 0
        }
    ]
};

plasma.loadSerializedLayout(layout);
