module MusicBrowser exposing (view)

import Element
import Element.Background
import Element.Events
import Element.Border
import Element.Font
import List.Extra
import Model exposing (Tab(..))
import Msg
import Color
import Bandcamp
import Element.Input
import Html.Attributes

playlists : Model.Model -> Element.Element Msg.Msg
playlists model =
    let
        attribs = [Element.clipX, Element.width <| Element.px 300, Element.height Element.fill, Element.Background.color Color.offWhite]

        viewLists =
            List.map
                (viewPlaylist model)
                model.playlists
    in
        Element.column
            attribs
            viewLists

view : Model.Model -> Element.Element Msg.Msg
view model =
    let
        localBrowser = Element.row
            [Element.clipY, Element.scrollbarY, Element.height Element.fill, Element.width Element.fill]
            [{-playlists,-} filesList]

        bcBrowser = Bandcamp.browser
                model.bandcamp

        filesList =
            case List.isEmpty model.files of
                True ->
                    Element.paragraph
                        [Element.Font.center, Element.padding 50]
                            [Element.text "Drop an audio file here to add it to your library or use the bandcamp tab."]
                False ->
                    Element.column
                        ([Element.clipY, Element.scrollbarY, Element.scrollbarY, Element.width Element.fill, Element.height Element.fill, Element.clipX, Element.scrollbarY])
                        (List.map (viewFileRef model) model.files)
        content = case model.tab of
            LocalTab -> localBrowser
            BandcampTab ->
                bcBrowser
                |> Element.map Msg.BandcampMsg
    in
        Element.column
            [Element.width Element.fill, Element.height Element.fill, Element.clipY, Element.scrollbarY]
            [tabs model, content]


viewTab : Model.Model -> String -> Model.Tab -> Element.Element Msg.Msg
viewTab model label tab =
    let
        background =
            if tab == model.tab
                then Color.blue
                else Color.playerGrey
        textColor =
            if tab == model.tab
                then Color.white
                else Color.black
        attribs =
            [ Element.centerX
            , Element.padding 10
            , Element.Background.color background
            , Element.Font.color textColor
            , Element.Border.rounded 5
            ]
        params =
            { onPress = Just <| Msg.TabClicked tab
            , label = Element.text label
            }
    in
        Element.Input.button attribs params

tabs model = Element.row [Element.spacing 10, Element.centerX, Element.padding 10] [
        viewTab model "Local" LocalTab
      , viewTab model "Bandcamp" BandcampTab
    ]

    -- <video controls="" autoplay="" name="media"><source src="file:///home/jan/Downloads/Various%20Artists%20-%204%20To%20The%20Floor%20Volume%2001/Ben%20Westbeech%20-%204%20To%20The%20Floor%20Volume%2001%20-%2039%20Falling%20(Deetron%20Paradise%20Vocal%20Remix).wav" type="audio/wav"></video>
viewFileRef model fileRef =
    let
        attribs = [Element.Events.onClick (Msg.Play fileRef)
            , Element.padding 10
            , Element.spacing 10
            , Element.width Element.fill
            , Element.mouseOver [Element.Background.color Color.blueTransparent]
            , Element.pointer
            ]

        playingMarkerBackground =
            if model.playback == Just fileRef
                then Element.Background.color Color.blue
                else Element.Background.color Color.white
        playingMarker =
            Element.el
                [ Element.width <| Element.px 8
                , Element.height <| Element.px 8
                , Element.Border.rounded 4
                , Element.moveUp 1 -- baseline correction
                , Element.centerY
                , playingMarkerBackground
                ]
                Element.none
        content =
            [ playingMarker
            , Element.paragraph [Element.htmlAttribute (Html.Attributes.style "white-space" "nowrap"), Element.clip, Element.width Element.fill] [Element.text fileRef.name]
            -- , Element.el [] (Element.text fileRef.path)
            ]
    in
        Element.row attribs content

viewPlaylist model name =
    let
        attribs = [-- Element.Events.onClick (Play fileRef)
            Element.padding 15
            , Element.spacing 15
            , Element.width Element.fill
            , Element.mouseOver [Element.Background.color Color.blueTransparent]
            , Element.pointer
            ]
        -- highlight curerntly selected playlist
        styleBackground =
            if model.activePlaylist == Just name
                then Element.Background.color Color.blue
                else Element.Background.color Color.white
        playingMarker =
            Element.el
                [ Element.width <| Element.px 8
                , Element.height <| Element.px 8
                , Element.Border.rounded 4
                , Element.moveUp 1 -- baseline correction
                , Element.centerY
                , styleBackground
                ]
                Element.none
        content =
            [ playingMarker
            , Element.text name
            -- , Element.el [] (Element.text fileRef.path)
            ]
    in
        Element.row attribs content

