module Main exposing (..)

-- Press buttons to increment and decrement a counter.
--
-- Read how it works:
--   https://guide.elm-lang.org/architecture/buttons.html
--


import Browser
import Bandcamp
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)
import Html.Attributes exposing (style)
import DropZone
import Element
import Element.Background
import Element.Events
import Element.Border
import List.Extra
import File
import Json.Decode as Decode
import Json.Encode as Encode
import Http
import Element.Font
import Url
import Model exposing (..)
import Msg exposing (..)

persist_ = always Cmd.none

persist : Model -> Cmd Msg
persist model =
    let
        encoded = encodeModel model
        params =
            { url = "http://localhost:8080/persist"
            , body = Http.jsonBody encoded
            , expect = Http.expectWhatever (always Saved)
            }
    in
    Http.post params

readDirectories : List String -> Cmd Msg
readDirectories directories =
    let
        encoded = Encode.list Encode.string directories
        params =
            { url = "http://localhost:8080/import"
            , body = Http.jsonBody encoded
            , expect = Http.expectJson FilesRead (Decode.list decodeFileRef)
            }
    in
    Http.post params


uriDecorder : Decode.Decoder DropPayload
uriDecorder =
    let
        filesDecoder = Decode.at
            ["dataTransfer", "files"]
            ( Decode.list (File.decoder |> Decode.andThen detect) |> Decode.map (List.filterMap identity)
            )

        detect : File.File -> Decode.Decoder (Maybe TransferItem)
        detect file =
            let
                isAudio = file |> File.mime |> String.contains "audio"
                isDir = File.mime file == ""
                decodeAudioFile =
                    decodeFileRef
                    |> Decode.map (DroppedFile >> Just)
            in
                case (isAudio, isDir) of
                    (True, _) ->
                        decodeAudioFile
                    (_, True) -> Decode.field "path" Decode.string |> Decode.map (DroppedDirectory >> Just)
                    _ -> Decode.succeed Nothing
    in
        filesDecoder

restore : Cmd Msg
restore =
    let
        params =
            {url = "http://localhost:8080/restore"
            , expect = Http.expectJson Restored decodeModel
            }
    in
    Http.get params



-- MAIN


main : Platform.Program () Model Msg
main =
  Browser.element
      { init = always init
      , update = update
      , view = view
      , subscriptions = always Sub.none
      }



-- MODEL



init : (Model, Cmd Msg)
init =
  (initModel, restore)

initModel : Model
initModel =
    {dropZone = DropZone.init
    , files = []
    , bandcampCookie = Nothing
    , playing = False
    , playback = Nothing
    , playlists = ["House" , "Jazz"]
    , activePlaylist = Just "Jazz"
    }


ensureUnique = List.Extra.uniqueBy .path

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    BandcampCookieRetrieved cookie ->
        let
            mdl = {model | bandcampCookie = Just cookie}
            cmds = Cmd.batch [
                    persist mdl
                  , Bandcamp.getInitData cookie
                    |> Cmd.map BandcampDataRetrieved
                ]
        in
        (mdl, cmds)
    Paused ->
        ({model | playing = False}, Cmd.none)
    Play fileRef ->
        let
            mdl = {model | playback = Just fileRef, playing = True}
        in
            (mdl, persist mdl)
    DropZoneMsg (DropZone.Drop files) ->
        let
            newAudioFiles =
                files
                |> List.filterMap (\droppedItem -> case droppedItem of
                        DroppedFile file -> Just file
                        DroppedDirectory _ -> Nothing
                    )
            newDirectories =
                files
                |> List.filterMap (\droppedItem -> case droppedItem of
                        DroppedFile _ -> Nothing
                        DroppedDirectory dirPath -> Just dirPath
                    )

            mdl = { model -- Make sure to update the DropZone model
                  | dropZone = DropZone.update (DropZone.Drop files) model.dropZone
                  , files = model.files ++ newAudioFiles |> ensureUnique
                  }
        in
        (mdl, Cmd.batch [persist mdl, readDirectories newDirectories ])
    DropZoneMsg a ->
        -- These are the other DropZone actions that are not exposed,
        -- but you still need to hand it to DropZone.update so
        -- the DropZone model stays consistent
        ({ model | dropZone = DropZone.update a model.dropZone }, Cmd.none)
    Saved -> (model, Cmd.none)
    Restored res ->
        case res of
            Err e -> (model, Cmd.none)
            Ok restored ->
                let
                    cmd = case restored.bandcampCookie of
                            Nothing -> Cmd.none
                            Just c -> Bandcamp.getInitData c
                                |> Cmd.map BandcampDataRetrieved
                in

                (restored, cmd)
    FilesRead res ->
        case res of
            Err e -> (model, Cmd.none)
            Ok newAudioFiles ->
                let
                    mdl =
                        { model
                        | files = model.files ++ newAudioFiles |> ensureUnique
                        }
                in
                    (mdl, persist mdl)
    BandcampDataRetrieved _ -> (model, Cmd.none)


-- VIEW


view : Model -> Html Msg
view model =
    let
        layout =
            Element.layout
                ([Element.clipY, Element.scrollbarY, jetMono, Element.height Element.fill])
    in
        layout <| view_ model

view_ : Model -> Element.Element Msg
view_ model =
    let
        bandcamp =
            Bandcamp.statusIndicator model.bandcampCookie
            |> Element.map Msg.BandcampCookieRetrieved
        header =
            Element.row
                [Element.Background.color playerGrey, Element.width Element.fill]
                [playback model, bandcamp]

        dropArea =
            Element.el
                <| [Element.width Element.fill
                , Element.height Element.fill
                , Element.clipY, Element.scrollbarY
                ] ++ dropAreaStyles model ++  dropHandler
    in
        dropArea 
        <| Element.column
            [Element.clipY, Element.scrollbarY, Element.width Element.fill, Element.height Element.fill]
            [header
            , browser model]

browser model =
    let
        v = Element.row
            [Element.clipY, Element.scrollbarY, Element.height Element.fill, Element.width Element.fill]
            [{-playlists,-} filesList]

        playlists =
                Element.column
                    ([Element.clipX, Element.width <| Element.px 300, Element.height Element.fill, Element.Background.color offWhite])
                    (List.map (viewPlaylist model) model.playlists)
        filesList =
            Element.column
                ([Element.clipY, Element.scrollbarY, Element.scrollbarY, Element.width Element.fill, Element.height Element.fill, Element.clipX, Element.scrollbarY])
                (List.map (viewFileRef model) model.files)
    in
        v
playerGrey = Element.rgb 0.95 0.955 0.96
offWhite = Element.rgb 0.97 0.975 0.98

playback : Model -> Element.Element Msg
playback model =
    let
        playbackBarAttribs =
            [Element.height <| Element.px 54, Element.spacing 5, Element.width Element.fill, Element.Background.color <| playerGrey]
        marqueeStyles = [draggable, Element.height Element.fill, Element.width (Element.fillPortion 1 |> Element.minimum 150), Element.Font.color blue]
        playingMarquee txt =
            Element.el
                marqueeStyles
                <| Element.el [Element.centerY] <| Element.html (Html.node "marquee" [] [Html.text txt])
        draggable = Element.htmlAttribute <| Html.Attributes.style "-webkit-app-region" "drag"
    in
        Element.row
         playbackBarAttribs
            <| case model.playback of
                Just f ->
                     [ playingMarquee f.name
                     , Element.el
                        [Element.width (Element.fillPortion 3 |> Element.minimum 150)]
                        (player model f)
                     ]
                Nothing ->
                    [playingMarquee "not playing"]

player : Model -> FileRef -> Element.Element Msg.Msg
player model {path, name} =
    let
        fileUri =
            "file://" ++ (String.split "/" path |> List.map Url.percentEncode |> String.join "/")
            |> Debug.log "fileUri"
        audioSrc = Html.Attributes.attribute "src"  fileUri
        attribs =
            [ Html.Attributes.autoplay False
            , audioSrc
            , Html.Attributes.type_ "audio/wav"
            , Html.Attributes.controls True
            , Html.Attributes.style "width" "auto"
            , Html.Attributes.attribute "playing" "true"
            ]
        a = Html.node
            "audio-player"
            attribs
            []
            |> Element.html
            |> Element.el [Element.width Element.fill]
    in
        a

blue = Element.rgb 0.2 0.2 0.8
blueTransparent = Element.rgba 0.2 0.2 0.8 0.1
white = Element.rgb 1 1 1

    -- <video controls="" autoplay="" name="media"><source src="file:///home/jan/Downloads/Various%20Artists%20-%204%20To%20The%20Floor%20Volume%2001/Ben%20Westbeech%20-%204%20To%20The%20Floor%20Volume%2001%20-%2039%20Falling%20(Deetron%20Paradise%20Vocal%20Remix).wav" type="audio/wav"></video>
viewFileRef model fileRef =
    let
        attribs = [Element.Events.onClick (Play fileRef)
            , Element.padding 10
            , Element.spacing 10
            , Element.width Element.fill
            , Element.mouseOver [Element.Background.color blueTransparent]
            , Element.pointer
            ]
        playingMarker =
            Element.el
                [ Element.width <| Element.px 8
                , Element.height <| Element.px 8
                , Element.Border.rounded 4
                , Element.moveUp 1 -- baseline correction
                , Element.centerY
                , if model.playback == Just fileRef then Element.Background.color blue else Element.Background.color white
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
            , Element.mouseOver [Element.Background.color blueTransparent]
            , Element.pointer
            ]
        playingMarker =
            Element.el
                [ Element.width <| Element.px 8
                , Element.height <| Element.px 8
                , Element.Border.rounded 4
                , Element.moveUp 1 -- baseline correction
                , Element.centerY
                , if model.activePlaylist == Just name then Element.Background.color blue else Element.Background.color white
                ]
                Element.none
        content =
            [ playingMarker
            , Element.text name
            -- , Element.el [] (Element.text fileRef.path)
            ]
    in
        Element.row attribs content




jetMono =
    Element.Font.family
        [ Element.Font.typeface "JetBrains Mono"
        , Element.Font.monospace
        ]

dropHandler : List (Element.Attribute Msg)
dropHandler =
    DropZone.dropZoneEventHandlers uriDecorder
    |> List.map (Element.htmlAttribute >> Element.mapAttribute DropZoneMsg)

dropAreaStyles {dropZone} =
    if DropZone.isHovering dropZone
        then [Element.Background.color (Element.rgb 0.8 8 1)]
    else
        []
