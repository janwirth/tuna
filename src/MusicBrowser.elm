module MusicBrowser exposing (view, resolveTrack)

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
import Track
import FileSystem
import Bandcamp.Model
import Bandcamp.Id
import Player
import Svg.Attributes
import Svg
import Html
import Html

view : Model.Model -> Element.Element Msg.Msg
view model =
    let
        localBrowser = Element.row
            [Element.clipY, Element.scrollbarY, Element.height Element.fill, Element.width Element.fill]
            [{-playlists,-} filesList]

        bcBrowser = Bandcamp.browser
                model.bandcamp
        filesList =
            case Track.noTracks model.tracks of
                True ->
                    Element.paragraph
                        [Element.Font.center, Element.padding 50]
                            [Element.text "Drop an audio file here to add it to your library or use the bandcamp tab."]
                False ->
                    let
                        currentlyViewedTracks = Track.tracksToList model.tracks
                    in

                        Element.column
                            ([Element.clipY, Element.scrollbarY, Element.scrollbarY, Element.width Element.fill, Element.height Element.fill, Element.clipX, Element.scrollbarY])
                            (List.map (viewTrack model) currentlyViewedTracks)
        content = case model.tab of
            LocalTab -> localBrowser
            BandcampTab ->
                bcBrowser
                |> Element.map Msg.BandcampMsg
    in
        Element.column
            [Element.width Element.fill, Element.height Element.fill, Element.clipY, Element.scrollbarY]
            [secondHeader model, content]

secondHeader model = Element.row [Element.padding 10, Element.width Element.fill] [tabs model, downloads model]

downloads model =
    let
        summary = downloadSummary model.bandcamp.downloads
    in
        Element.el [Element.alignRight] summary


downloadSummary : Bandcamp.Model.Downloads -> Element.Element msg
downloadSummary dls =
    let
        {error, status} = Bandcamp.Model.summarizeDownloads dls
    in case status of
        Bandcamp.Model.AllDone -> Element.text "No Downloads"
        Bandcamp.Model.SomeLoading pct count -> progressCircle pct count

progressCircle : Int -> Int -> Element.Element msg
progressCircle pct numberOfDls =
    let
        progress =
            Svg.circle
                [ Svg.Attributes.cx "15"
                , Svg.Attributes.cy "15"
                , Svg.Attributes.r "13"
                , Svg.Attributes.fill "transparent"
                , Svg.Attributes.stroke "black"
                , Svg.Attributes.strokeWidth "2"
                , Html.Attributes.attribute "stroke-dashoffset" (String.fromFloat ((toFloat (100 - pct)) * 0.88))
                , Html.Attributes.attribute "stroke-dasharray" "88"
                ]
                []

        path =
            Svg.circle
                [ Svg.Attributes.cx "15"
                , Svg.Attributes.cy "15"
                , Svg.Attributes.r "13"
                , Svg.Attributes.fill "transparent"
                , Svg.Attributes.stroke "#eee"
                , Svg.Attributes.strokeWidth "1"
                ]
                []

        style =
            Html.node "style" []
            [Html.text "circle {transition: stroke-dashoffset 0.2s ease-in-out}"]

        size = 30
        svg =
          Svg.svg
            [ Svg.Attributes.width "30"
            , Svg.Attributes.height "30"
            , Svg.Attributes.viewBox "0 0 30 30"
            ]
            [ 
              path
            , progress
            , style
            ]
        count =
            Element.el
                [ Element.centerX
                , Element.centerY
                , Element.Font.size 16
                ] (Element.text (String.fromInt numberOfDls))
    in
        Element.html svg
        |> Element.el [Element.inFront count]
viewTrack : Model.Model -> Track.Track -> Element.Element Msg.Msg
viewTrack model track =
    case resolveSource model (Track.source track) of
        Ok fileRef -> viewTrackHelp model (Track.getId track) fileRef
        Err err -> Element.text "Track not playable"



viewTrackHelp : Model.Model -> Track.Id -> FileSystem.FileRef -> Element.Element Msg.Msg
viewTrackHelp model id fileRef =
    let
        attribs = [Element.Events.onClick (Msg.PlayerMsg (Player.newQueue id model.tracks))
            , Element.padding 10
            , Element.spacing 10
            , Element.width Element.fill
            , Element.mouseOver [Element.Background.color Color.blueTransparent]
            , Element.pointer
            ]

        playingMarkerBackground =
            if Player.getCurrent model.player == Just id
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

resolveTrack : Model.Model -> Track.Id -> Result String (Track.TrackData, FileSystem.FileRef)
resolveTrack model id =
    case Track.getById id model.tracks of
        Just track -> resolveSource model (Track.source track) |> Result.map (Tuple.pair (Track.data track))
        Nothing -> Err "Track not found"

resolveSource : Model.Model -> Track.TrackSource -> Result String FileSystem.FileRef
resolveSource {bandcamp, tracks} source =
    case source of
        (Track.BandcampPurchase purchase_id track_number) ->
            case Bandcamp.Id.getBy purchase_id bandcamp.downloads of
                Just download -> case download of
                    Bandcamp.Model.Completed fileRefs ->
                        case List.Extra.getAt track_number fileRefs of
                            Just fileRef ->
                                Ok fileRef
                            Nothing ->
                                Err "Track not found in downloads"
                    _ -> Err "Download not completed"
                Nothing -> Err "No Download"
        (Track.LocalFile s) -> Ok s

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

tabs model = Element.row [Element.spacing 10, Element.centerX] [
        viewTab model "Local" LocalTab
      , viewTab model "Bandcamp" BandcampTab
    ]

type alias TrackToView =
    { id : Track.Id
    , name : String
    , file : Maybe FileSystem.Path
    }

type alias Annotation = String
