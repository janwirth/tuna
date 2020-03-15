module MusicBrowser exposing (view, resolveTrack)

import Element
import Element.Background
import Element.Events
import Element.Border
import Element.Font
import List.Extra
import Url
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
import Html.Events
import Set
import InfiniteList
import Json.Decode as Decode

type ItemMsg =
    SetTag Int String
    | Clicked Int

setTagOnBlur : Int -> Html.Attribute ItemMsg
setTagOnBlur listIdx =
    Html.Events.on
        "blur"
        (Decode.map (SetTag listIdx) targetValue)

targetValue : Decode.Decoder String
targetValue = Decode.at ["target", "value" ] Decode.string

itemView : Maybe Int -> Int -> Int -> Track.Track -> Html.Html ItemMsg
itemView playback _ listIdx track =
    let
        height = Html.Attributes.style "height" "20px"
        class =
            Html.Attributes.class
                <| (if playback == Just listIdx then "track playing" else "track") ++
                (if modBy 2 listIdx == 1 then " zebra" else "")
        tagsInput =
            Html.input [Html.Attributes.value track.tags, Html.Events.onInput (SetTag listIdx)] []
        playButton =
                Html.button playButtonAttribs [Html.text "▶️"]
        playButtonAttribs =
            [Html.Events.onClick (Clicked listIdx)]
        title = Html.div [Html.Attributes.class "title"] [Html.text track.title]
        artist = Html.div [Html.Attributes.class "artist"] [Html.text track.artist]
        album = Html.div [Html.Attributes.class "album"] [Html.text track.album]
        actualItem =
            Html.div
                [class, height]
                [playButton
                , title
                , artist
                , album
                , tagsInput]
    in
        actualItem

view : Model.Model -> Element.Element Msg.Msg
view model =
    let
        playback = Player.getCurrent model.player

        config : InfiniteList.Config Track.Track ItemMsg
        config =
            InfiniteList.config
                { itemView = itemView playback
                , itemHeight = InfiniteList.withConstantHeight 20
                , containerHeight = 1000
                }
        localBrowser = Element.column
            [Element.clipY, Element.scrollbarY, Element.height Element.fill, Element.width Element.fill]
            [{-playlists,-}pendingFiles, tracksList]

        pendingFiles =
            case Set.size model.pendingFiles of
                0 -> Element.none
                count -> Element.text (String.fromInt count)


        allTracks = model.tracks ++ Bandcamp.toTracks model.bandcamp
        bcBrowser = Bandcamp.browser
                model.bandcamp
        tracksList =
            case List.isEmpty allTracks of
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
                        processItemMsg msg =
                            case msg of
                                Clicked idx ->
                                    (makeQueue idx |> Player.SongClicked |> Msg.PlayerMsg)
                                SetTag idx tags -> Msg.TagChanged idx tags
                        items =
                                [ InfiniteList.view config model.infiniteList allTracks
                                |> Html.map processItemMsg
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
    resolveSource model track.source
    |> viewTrackHelp model trackId track



viewTrackHelp : Model.Model -> Track.Id -> Track.Track -> String -> Element.Element Track.Id
viewTrackHelp model id track src =
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
            , Element.paragraph [Element.htmlAttribute (Html.Attributes.style "white-space" "nowrap"), Element.clip, Element.width Element.fill] [Element.text track.title]
            -- , Element.el [] (Element.text fileRef.path)
            ]
    in
        Element.row attribs content

resolveTrack : Model.Model -> Track.Id -> Result String (Track.Track, String)
resolveTrack model id =
    case List.Extra.getAt id (model.tracks ++ Bandcamp.toTracks model.bandcamp) of
        Just track -> Ok (resolveSource model track.source |> (Tuple.pair track))
        Nothing -> Err "Track not found"

resolveSource : Model.Model -> Track.TrackSource -> String
resolveSource {bandcamp, tracks} source =
    case source of
        (Track.BandcampPurchase playbackUrl purchase_id) -> playbackUrl
        (Track.LocalFile {path}) -> fileUri path

fileUri path =
    "file://" ++ (String.split "/" path |> List.map Url.percentEncode |> String.join "/")

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
