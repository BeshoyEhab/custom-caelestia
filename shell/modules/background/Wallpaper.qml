pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    property string source: Wallpapers.current
    property CachingImage current
    property bool completed
    readonly property bool isVideo: Images.isVideo(source)

    function wallpaperFillMode(): int {
        switch (GlobalConfig.background.wallpaperMode) {
        case "fit": return Image.PreserveAspectFit;
        case "stretch": return Image.Stretch;
        default: return Image.PreserveAspectCrop;
        }
    }

    function videoFillMode(): int {
        switch (GlobalConfig.background.wallpaperMode) {
        case "fit": return VideoOutput.PreserveAspectFit;
        case "stretch": return VideoOutput.Stretch;
        default: return VideoOutput.PreserveAspectCrop;
        }
    }

    function imagePathFor(src: string): string {
        // Videos show their extracted first-frame thumbnail as a poster
        // behind/while the looping video buffers.
        return Images.isVideo(src) ? Wallpapers.thumbFor(src) : src;
    }

    function fileUrlFor(path: string): string {
        // MediaPlayer needs a real URL; a plain absolute path is mistaken
        // for a Qt resource ("Attempting to play invalid Qt resource").
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    onSourceChanged: {
        if (!source)
            current = null;
        else
            current = imgComp.createObject(this, {
                path: imagePathFor(source),
                fillMode: wallpaperFillMode()
            });
    }

    Component.onCompleted: {
        if (source)
            Qt.callLater(() => {
                current = imgComp.createObject(this, {
                    path: imagePathFor(source),
                    fillMode: wallpaperFillMode()
                });
                completed = true;
            });
    }

    Video {
        id: video

        // Above the (dynamically created, poster) images: they are appended
        // as later siblings so without this they would cover the video.
        z: 1
        anchors.fill: parent
        visible: root.isVideo
        source: root.isVideo ? fileUrlFor(root.source) : ""
        autoPlay: true
        muted: true
        volume: 0
        loops: MediaPlayer.Infinite
        fillMode: root.videoFillMode()

        opacity: 0

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState)
                videoFade.start();
        }

        Anim on opacity {
            id: videoFade

            type: Anim.SlowEffects
            running: false
            to: 1
        }
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image or video files")
                            filters: Images.validImageExtensions.concat(Images.validVideoExtensions)
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

            anchors.fill: parent

            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== img && root.current?.status === Image.Ready
                interval: anim.duration
                onTriggered: img.destroy()
            }
        }
    }
}
