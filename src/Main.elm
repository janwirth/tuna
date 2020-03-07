port module Main exposing (..)

-- Press buttons to increment and decrement a counter.
--
-- Read how it works:
--   https://guide.elm-lang.org/architecture/buttons.html
--


import Browser
import MusicBrowser
import Color
import Browser.Navigation
import Element.Input
import Url
import Dict
import FileSystem
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
import Subscriptions exposing (subscriptions)

type alias Flags = Decode.Value

port persist_ : Encode.Value -> Cmd msg
port import_ : List String -> Cmd msg
port bandcamp_import : Int -> Cmd msg

persist : Model -> Cmd msg
persist =
    encodeModel >> persist_

hooks : Msg.Msg -> (Model.Model, Cmd Msg.Msg) -> (Model.Model, Cmd Msg.Msg)
hooks msg (model, cmd) =
    case msg of
        Msg.BandcampMsg (Bandcamp.DownloadCompleted purchase_id) ->
            (model, Cmd.batch [cmd, bandcamp_import purchase_id, persist model])
        _ -> (model, cmd)

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


-- MAIN


main : Platform.Program Flags Model Msg
main =
  Browser.application
      { init = init
      , update = updateAndHooks
      , view = view
      , subscriptions = subscriptions
      , onUrlChange = always Paused
      , onUrlRequest = always Paused
      }

updateAndHooks msg = update msg >> hooks msg
-- MODEL



init : Flags -> Url.Url -> Browser.Navigation.Key -> (Model, Cmd Msg)
init flags url key =
    let
        decoded =
            Decode.decodeValue decodeModel flags
            |> Result.toMaybe
            |> Maybe.withDefault Model.init
        cmd = Bandcamp.initCmd decoded.bandcamp
            |> Cmd.map Msg.BandcampMsg
    in
        (decoded, cmd)


ensureUnique = List.Extra.uniqueBy .path

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    BandcampMsg bmsg ->
        let
            (b, cmd) = Bandcamp.update bmsg model.bandcamp
            mdl = {model | bandcamp = b}
        in
            (mdl, Cmd.batch [persist mdl, Cmd.map Msg.BandcampMsg cmd])
    TabClicked newTab -> ({model | tab = newTab}, Cmd.none)
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
        (mdl, Cmd.batch [persist mdl, FileSystem.scan_directories newDirectories ])
    DropZoneMsg a ->
        -- These are the other DropZone actions that are not exposed,
        -- but you still need to hand it to DropZone.update so
        -- the DropZone model stays consistent
        ({ model | dropZone = DropZone.update a model.dropZone }, Cmd.none)
    Saved -> (model, Cmd.none)
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


-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        layout =
            Element.layout
                ([Element.clipY, Element.scrollbarY, jetMono, Element.height Element.fill])
        body = model |> view_ |> layout |> List.singleton
    in
        {title = "Tuna", body = body}
view_ : Model -> Element.Element Msg
view_ model =
    let
        header =
            Element.row
                [Element.Background.color Color.playerGrey, Element.width Element.fill]
                [playback model]

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
            , MusicBrowser.view model
            ]

playback : Model -> Element.Element Msg
playback model =
    let
        playbackBarAttribs =
            [ Element.height <| Element.px 54
            , Element.spacing 5
            , Element.width Element.fill
            , Element.Background.color <| Color.playerGrey
            ]
        marqueeStyles =
            [ draggable
            , Element.height Element.fill
            , Element.width (Element.fillPortion 1 |> Element.minimum 150)
            , Element.Font.color Color.blue
            ]
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
