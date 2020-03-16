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
    SetTag Track.Id String
    | Clicked Track.Id

targetValue : Decode.Decoder String
targetValue = Decode.at ["target", "value" ] Decode.string

itemView : Model.Model -> Maybe Track.Id -> Int -> Int -> Track.Track -> Html.Html ItemMsg
itemView model playback _ listIdx track =
    let
        customTags : Set.Set String
        customTags = String.split " " track.tags |> Set.fromList
        tagsWithoutQuick : String
        tagsWithoutQuick =
            Set.remove model.quickTag customTags
            |> Set.toList
            |> String.join " "

        quickTagBadge : Html.Html ItemMsg
        quickTagBadge =
            let
                active : Bool
                active =
                    Set.member model.quickTag customTags
                toggled =
                    String.join " " <| Set.toList <| if active
                        then Set.remove model.quickTag customTags
                        else Set.insert model.quickTag customTags
            in
                Html.button
                    [Html.Events.onClick <| SetTag track.id toggled] [Html.text model.quickTag]

        height = Html.Attributes.style "height" "20px"
        class =
            Html.Attributes.class
                <| (if playback == Just track.id then "track playing" else "track") ++
                (if modBy 2 listIdx == 1 then " zebra" else "")
        tagsInput =
            Html.input [Html.Attributes.value track.tags, Html.Events.onInput (SetTag track.id)] []
        playButton =
                Html.button playButtonAttribs [Html.text "▶️"]
        playButtonAttribs =
            [Html.Events.onClick (Clicked track.id)]
        sourceHint = case track.source of
            Track.BandcampHeart _ _ -> Html.text "💙"
            Track.BandcampPurchase _ _ -> Html.text "💲"
            Track.LocalFile _ -> Html.text "📁"
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
                , sourceHint
                , quickTagBadge
                , tagsInput
                ]
    in
        actualItem

view : Model.Model -> Element.Element Msg.Msg
view model =
    let
        playback : Maybe Track.Id
        playback = Player.getCurrent model.player

        config : InfiniteList.Config Track.Track ItemMsg
        config =
            InfiniteList.config
                { itemView = itemView model playback
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


        visibleTracks =
            case model.quickTagOnly of
                True -> List.filter (\{tags} -> String.contains model.quickTag tags) model.tracks
                False -> model.tracks
        bcBrowser = Bandcamp.browser
                model.bandcamp
        tracksList =
            case List.isEmpty visibleTracks of
                True ->
                    Element.paragraph
                        [Element.Font.center, Element.padding 50]
                            [Element.text "Drop an audio file here to add it to your library or use the bandcamp tab."]
                False ->
                    let
                        makeQueue : Track.Id -> Player.Queue
                        makeQueue id =
                            visibleTracks
                            |> List.Extra.splitWhen (\someTrack -> id == someTrack.id)
                            |> Maybe.andThen (Tuple.second >> List.map .id >> List.Zipper.fromList)
                            |> Maybe.withDefault (List.Zipper.singleton id)

                        processItemMsg : ItemMsg -> Msg.Msg
                        processItemMsg msg =
                            case msg of
                                Clicked idx ->
                                    (makeQueue idx |> Player.SongClicked |> Msg.PlayerMsg)
                                SetTag idx tags -> Msg.TagChanged idx tags

                        items : List (Html.Html Msg.Msg)
                        items =
                                [ InfiniteList.view config model.infiniteList visibleTracks
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

secondHeader model =
    Element.row
        [Element.padding 10, Element.width Element.fill, Element.spacing 10]
        [ quickTagControls model
        , tabs model
        , downloads model
        ]

quickTagControls : Model.Model -> Element.Element Msg.Msg
quickTagControls model =
    Element.row [Element.spacing 10] [
        Element.Input.text [Element.width (Element.px 100)]
            { placeholder = Just <| Element.Input.placeholder [] <| Element.text "e.g. genre:house"
            , text = model.quickTag
            , onChange = Msg.SetQuickTag
            , label = Element.Input.labelLeft [Element.centerY] (Element.text "Quicktag")
            }
        , Element.Input.button
            []
            { label = Element.text "toggle"
            , onPress = Just Msg.ToggleQuickTag
            }
        ]

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

resolveTrack : Model.Model -> Track.Id -> Result String (Track.Track, String)
resolveTrack model id =
    case List.Extra.find (\someTrack -> someTrack.id == id) model.tracks of
        Just track -> Ok (resolveSource model track.source |> (Tuple.pair track))
        Nothing -> Err "Track not found"

resolveSource : Model.Model -> Track.TrackSource -> String
resolveSource {bandcamp, tracks} source =
    case source of
        (Track.BandcampPurchase playbackUrl purchase_id) -> playbackUrl
        (Track.BandcampHeart playbackUrl purchase_id) -> playbackUrl
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

tabs model =
    Element.row [Element.spacing 10, Element.alignLeft]
    [  viewTab model "Local" LocalTab
      , viewTab model "Bandcamp" BandcampTab
    ]

type alias TrackToView =
    { id : Track.Id
    , name : String
    , file : Maybe FileSystem.Path
    }

type alias Annotation = String
