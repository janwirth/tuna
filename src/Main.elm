module Main exposing (..)

-- Press buttons to increment and decrement a counter.
--
-- Read how it works:
--   https://guide.elm-lang.org/architecture/buttons.html
--


import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)
import Html.Attributes exposing (style)
import DropZone exposing (..)
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

restore : Cmd Msg
restore =
    let
        params =
            {url = "http://localhost:8080/restore"
            , expect = Http.expectJson Restored decodeModel
            }
    in
    Http.get params

type alias DropZoneModel = DropZone.Model

encodeDropZoneModel _ = Encode.null
decodeDropZoneModel = Decode.succeed DropZone.init

-- [decgen-start]
type alias FileRef = {name : String, path: String}

type alias Model =
    { dropZone : DropZoneModel
    , files : List FileRef
    , playback : Maybe FileRef
    , playlists : List String
    , activePlaylist : Maybe String
    }

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeFileRef =
   Decode.map2
      FileRef
         ( Decode.field "name" Decode.string )
         ( Decode.field "path" Decode.string )

decodeModel =
   Decode.map5
      Model
         ( Decode.field "dropZone" decodeDropZoneModel )
         ( Decode.field "files" (Decode.list decodeFileRef) )
         ( Decode.field "playback" (Decode.maybe decodeFileRef) )
         ( Decode.field "playlists" (Decode.list Decode.string) )
         ( Decode.field "activePlaylist" (Decode.maybe Decode.string) )

encodeFileRef a =
   Encode.object
      [ ("name", Encode.string a.name)
      , ("path", Encode.string a.path)
      ]

encodeMaybeFileRef a =
   case a of
      Just b->
         encodeFileRef b
      Nothing->
         Encode.null

encodeMaybeString a =
   case a of
      Just b->
         Encode.string b
      Nothing->
         Encode.null

encodeModel a =
   Encode.object
      [ ("dropZone", encodeDropZoneModel a.dropZone)
      , ("files", (Encode.list encodeFileRef) a.files)
      , ("playback", encodeMaybeFileRef a.playback)
      , ("playlists", (Encode.list Encode.string) a.playlists)
      , ("activePlaylist", encodeMaybeString a.activePlaylist)
      ] 
-- [decgen-end]




uriDecorder =
    Decode.at ["dataTransfer", "files"] (Decode.list (Decode.map2 Tuple.pair decodeFileRef File.decoder))


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
    , playback = Nothing
    , playlists = ["House" , "Jazz"]
    , activePlaylist = Just "Jazz"
    }



-- UPDATE


type Msg
  = DropZoneMsg (DropZone.DropZoneMessage (List (FileRef, File.File)))
  | Play FileRef
  | Saved
  | Restored (Result Http.Error Model)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Play fileRef ->
        let
            mdl = {model | playback = Just fileRef}
        in
            (mdl, persist mdl)
    DropZoneMsg (DropZone.Drop files) ->
        let
            audioOnly =
                files
                |> List.filter (Tuple.second >> File.mime >> String.contains "audio")
                |> List.map Tuple.first
            ensureUnique = List.Extra.uniqueBy .path

            mdl = { model -- Make sure to update the DropZone model
                  | dropZone = DropZone.update (DropZone.Drop files) model.dropZone
                  , files = model.files ++ audioOnly |> ensureUnique
                  }
        in
        (mdl, persist mdl)
    DropZoneMsg a ->
        -- These are the other DropZone actions that are not exposed,
        -- but you still need to hand it to DropZone.update so
        -- the DropZone model stays consistent
        ({ model | dropZone = DropZone.update a model.dropZone }, Cmd.none)
    Saved -> (model, Cmd.none)
    Restored res ->
        case Debug.log "res" res of
            Err e -> (model, Cmd.none)
            Ok restored -> (restored, Cmd.none)


-- VIEW


view : Model -> Html Msg
view model =
    Element.layout [jetMono, Element.height Element.fill] <| view_ model

view_ : Model -> Element.Element Msg
view_ model =
    let
        dropArea =
            Element.el
                <| [Element.width Element.fill
                , Element.height Element.fill 
                ] ++ dropAreaStyles model ++  dropHandler

        playlists =
                Element.column
                    ([Element.clipX, Element.width <| Element.px 300, Element.height Element.fill, Element.Background.color playerGrey])
                    (List.map (viewPlaylist model) model.playlists)
        filesList =
            Element.column
                ([Element.width Element.fill, Element.height Element.fill])
                (List.map (viewFileRef model) model.files)
    in
        dropArea 
        <| Element.column
            [Element.width Element.fill, Element.height Element.fill]
            [playback model, Element.row [Element.height Element.fill, Element.width Element.fill] [playlists, filesList]]

playerGrey = Element.rgb 0.95 0.955 0.96

playback : Model -> Element.Element Msg
playback model =
    let
        playingMarquee txt =
            Element.el
                [Element.width (Element.fillPortion 1 |> Element.minimum 150), Element.Font.color blue]
                <| Element.html (Html.node "marquee" [] [Html.text txt])
    in
        Element.row
         [Element.height <| Element.px 54, Element.spacing 5, Element.width Element.fill, Element.Background.color <| playerGrey]
            <| case model.playback of
                Just f ->
                     [ playingMarquee f.name
                     , Element.el
                        [Element.width (Element.fillPortion 3 |> Element.minimum 150)]
                        (player f)
                     ]
                Nothing ->
                    [playingMarquee "not playing"]

player {path, name} =
    let
        fileUri =
            "file://" ++ ((String.replace name "" path) ++ name)
        audioSrc = Html.Attributes.src fileUri
        attribs =
            [ Html.Attributes.autoplay True
            , audioSrc
            , Html.Attributes.type_ "audio/wav"
            , Html.Attributes.controls True
            , Html.Attributes.style "width" "auto"
            ]
        a = Html.node
            "audio"
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
            , Element.text fileRef.name
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

dropHandler =
    dropZoneEventHandlers uriDecorder
    |> List.map (Element.htmlAttribute >> Element.mapAttribute DropZoneMsg)

dropAreaStyles {dropZone} =
    if DropZone.isHovering dropZone
        then [Element.Background.color (Element.rgb 0.8 8 1)]
    else
        []



