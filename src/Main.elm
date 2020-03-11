port module Main exposing (..)

-- Press buttons to increment and decrement a counter.
--
-- Read how it works:
--   https://guide.elm-lang.org/architecture/buttons.html
--


import Browser
import MusicBrowser
import Player
import Color
import Browser.Navigation
import Element.Input
import Url
import Dict
import FileSystem
import Bandcamp
import Bandcamp.Downloader
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
import Queue
import Track

port persist_ : Encode.Value -> Cmd msg
port import_ : List String -> Cmd msg
port bandcamp_import : Int -> Cmd msg

persist : Model -> Cmd msg
persist =
    Model.encodeUserModel >> persist_

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
                    FileSystem.decodeFileRef
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


main : Platform.Program Model.Flags Model Msg
main =
  Browser.application
      { init = init
      , update = updateWithHooks
      , view = view
      , subscriptions = subscriptions
      , onUrlChange = always UrlChanged
      , onUrlRequest = always UrlRequested
      }

updateWithHooks msg model =
    model
    |> update msg
    |> hooks msg
-- MODEL



init : Model.Flags -> Url.Url -> Browser.Navigation.Key -> (Model.Model, Cmd Msg)
init flags url key =
    let
        decoded = Model.decodeOrInit flags url key
        cmd = Bandcamp.initCmd decoded.bandcamp
            |> Cmd.map Msg.BandcampMsg
    in
        (decoded, cmd)


ensureUnique = List.Extra.uniqueBy .path

hooks msg (model, cmd) =
    let
        (pm, pc) = persistHook msg model
        im = importHook msg pm
    in
        (im, Cmd.batch [pc, cmd])

persistHook msg model =
    (model, persist model)

importHook msg model =
    case msg of
        -- add new files from bandcamp
        BandcampMsg (Bandcamp.DownloaderMsg (Bandcamp.Downloader.FilesScanned scanResult)) ->
            let
                (tracks, seed) =
                    Track.addBandcamp
                        model.seed
                        scanResult
                        model.tracks
                        |> Debug.log "t"
            in
            {model | tracks = tracks, seed = seed}
        _ -> model

{-
Use writer monad that also returns a new seed
-}
update : Msg -> Model.Model -> (Model.Model, Cmd Msg)
update msg model =
  case msg of
    BandcampMsg bmsg ->
        let
            (b, cmd) = Bandcamp.update bmsg model.bandcamp
            mdl = {model | bandcamp = b}
        in
            (mdl, Cmd.batch [persist mdl, Cmd.map Msg.BandcampMsg cmd])
    TabClicked newTab -> ({model | tab = newTab}, Cmd.none)
    PlayerMsg msg_ ->
        ({model | player = Player.update msg_ model.player}, Cmd.none)
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
            (tracks, seed) = Track.addLocal model.seed newAudioFiles model.tracks

            mdl = { model -- Make sure to update the DropZone model
                  | dropZone = DropZone.update (DropZone.Drop files) model.dropZone
                  , tracks = tracks
                  , seed = seed
                  }
        in
        (mdl, Cmd.batch [persist mdl, FileSystem.scan_directories newDirectories ])
    DropZoneMsg a ->
        -- These are the other DropZone actions that are not exposed,
        -- but you still need to hand it to DropZone.update so
        -- the DropZone model stays consistent
        ({ model | dropZone = DropZone.update a model.dropZone }, Cmd.none)
    FilesRead res ->
        case res of
            Err e -> (model, Cmd.none)
            Ok newAudioFiles ->
                let
                    (tracks, seed) = Track.addLocal model.seed newAudioFiles model.tracks
                    mdl = {model | tracks = tracks, seed = seed}
                in
                    (mdl, persist mdl)
    UrlRequested -> (model, Cmd.none)
    UrlChanged -> (model, Cmd.none)

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
                [Player.view (MusicBrowser.resolveTrack model) model.player]
                |> Element.map PlayerMsg

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
