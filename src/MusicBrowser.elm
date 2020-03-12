module MusicBrowser exposing (view, resolveTrack)

import Element
import Element.Background
import Element.Events
import Element.Border
import Element.Font
import List.Extra
import List.Zipper
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
import Set
import InfiniteList


config : InfiniteList.Config Track.Track Track.Id
config =
    InfiniteList.config
        { itemView = itemView
        , itemHeight = InfiniteList.withConstantHeight 20
        , containerHeight = 500
        }

itemView : Int -> Int -> Track.Track -> Html.Html Track.Id
itemView idx listIdx track =
    let
        actualItem =
            Element.el
                [Element.Events.onClick listIdx]
                (Element.text track.title)
        ret = Element.layoutWith
                { options = [Element.noStaticStyleSheet]}
                [ Element.height (Element.px 20 |> Element.maximum 20)
                , Element.width Element.fill
                , Element.padding 5
                ] actualItem
    in
        Html.div [Html.Attributes.style "height" "20px"] [ret]

view : Model.Model -> Element.Element Msg.Msg
view model =
    let
        localBrowser = Element.column
            [Element.clipY, Element.scrollbarY, Element.height Element.fill, Element.width Element.fill]
            [{-playlists,-}pendingFiles, tracksList]

        pendingFiles =
            case Set.size model.pendingFiles of
                0 -> Element.none
                count -> Element.text (String.fromInt count)

        bcBrowser = Bandcamp.browser
                model.bandcamp
        tracksList =
            case List.isEmpty model.tracks of
                True ->
                    Element.paragraph
                        [Element.Font.center, Element.padding 50]
                            [Element.text "Drop an audio file here to add it to your library or use the bandcamp tab."]
                False ->
                    let
                        makeQueue idx =
                            List.Zipper.fromCons
                                idx
                                (List.range (idx + 1) ((List.length model.tracks) - 1))
                        items =
                                [ InfiniteList.view config model.infiniteList model.tracks
                                |> Html.map (makeQueue >> Player.SongClicked >> Msg.PlayerMsg)
                                ]
                        infList =
                            Html.div
                                [ 
                                  Html.Attributes.style "width" "100%"
                                , Html.Attributes.style "height" "100%"
                                , Html.Attributes.style "overflow-x" "hidden"
                                , Html.Attributes.style "overflow-y" "auto"
                                , Html.Attributes.style "-webkit-overflow-scrolling" "touch"
                                , InfiniteList.onScroll Msg.InfiniteListMsg
                                ] items
                    in
                        Element.el
                            ([Element.clipY, Element.scrollbarY, Element.scrollbarY, Element.width Element.fill, Element.height Element.fill, Element.clipX, Element.scrollbarY])
                            (Element.html infList)
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

viewTrack : Model.Model -> Int -> Track.Track -> Element.Element Track.Id
viewTrack model trackId track =
    case resolveSource model track.source of
        Ok fileRef -> viewTrackHelp model trackId fileRef
        Err err -> Element.text "Track not playable"



viewTrackHelp : Model.Model -> Track.Id -> FileSystem.FileRef -> Element.Element Track.Id
viewTrackHelp model id fileRef =
    let
        attribs = [Element.Events.onClick id
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

resolveTrack : Model.Model -> Track.Id -> Result String (Track.Track, FileSystem.FileRef)
resolveTrack model id =
    case List.Extra.getAt id model.tracks of
        Just track -> resolveSource model track.source |> Result.map (Tuple.pair track)
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
