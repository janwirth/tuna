module Player exposing
    ( view
    , Queue
    , Model
    , init
    , encodeModel
    , decodeModel
    , Msg(..)
    , getCurrent
    , update
    )

import List.Extra
import List.Zipper
import Dict
import Track
import Element
import Element.Background
import Element.Font
import Html.Events
import Html
import FileSystem
import Html.Attributes
import Color
import Url
import Json.Decode as Decode
import Json.Encode as Encode

type alias Queue = List.Zipper.Zipper Int

init = NoTrack

update : Msg -> Model -> Model
update msg model =
    case (msg, model) of
        (PauseClicked, Playing q) -> Paused q
        (PlayClicked, Paused q) -> Playing q
        (PlayClicked, Ended q) -> Playing (restart q)
        (SongEnded, Playing q) ->
            case List.Zipper.next q of
                Nothing -> Ended q
                Just q_ -> Playing q_
        (QueueCreated (Just q), _) -> Playing q
        _ -> model

restart : Queue -> Queue
restart = List.Zipper.first

-- [generator-start]
type alias Zipper = {current: Track.Id, after: List Track.Id, before : List Track.Id}

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeZipper =
   Decode.map3
      Zipper
         ( Decode.field "current" Decode.int )
         ( Decode.field "after" (Decode.list Decode.int) )
         ( Decode.field "before" (Decode.list Decode.int) )

encodeZipper a =
   Encode.object
      [ ("current", Encode.int a.current)
      , ("after", (Encode.list Encode.int) a.after)
      , ("before", (Encode.list Encode.int) a.before)
      ] 
-- [generator-end]
encodeQueue : Queue -> Encode.Value
encodeQueue  q = encodeZipper (Zipper (List.Zipper.current q)(List.Zipper.after q)(List.Zipper.before q))

decodeQueue : Decode.Decoder Queue
decodeQueue =
    decodeZipper
    |> Decode.map (\{before, current, after} -> List.Zipper.from before current after)

type Msg =
    PauseClicked
  | SongClicked Int
  | PlayClicked
  | SongEnded
  | QueueCreated (Maybe Queue)

-- [generator-start]
type Model =
        NoTrack
    | Playing Queue
    | Paused Queue
    | Ended Queue

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeModel =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeModelHelp

decodeModelHelp constructor =
   case constructor of
      "NoTrack" ->
         Decode.succeed NoTrack
      "Playing" ->
         Decode.map
            Playing
               ( Decode.field "A1" decodeQueue )
      "Paused" ->
         Decode.map
            Paused
               ( Decode.field "A1" decodeQueue )
      "Ended" ->
         Decode.map
            Ended
               ( Decode.field "A1" decodeQueue )
      other->
         Decode.fail <| "Unknown constructor for type Model: " ++ other

encodeModel a =
   case a of
      NoTrack ->
         Encode.object
            [ ("Constructor", Encode.string "NoTrack")
            ]
      Playing a1->
         Encode.object
            [ ("Constructor", Encode.string "Playing")
            , ("A1", encodeQueue a1)
            ]
      Paused a1->
         Encode.object
            [ ("Constructor", Encode.string "Paused")
            , ("A1", encodeQueue a1)
            ]
      Ended a1->
         Encode.object
            [ ("Constructor", Encode.string "Ended")
            , ("A1", encodeQueue a1)
            ] 
-- [generator-end]
getCurrent = getQueue >> Maybe.map List.Zipper.current
getQueue : Model -> Maybe Queue
getQueue model =
    case model of
        Playing q -> Just q
        Paused q -> Just q
        Ended q -> Just q
        NoTrack -> Nothing

-- isPlaying : Model -> Bool
-- isPlaying m =
--     case m of
--         Playing q -> True
--         _ -> False

view : (Track.Id -> Result String (Track.Track, FileSystem.FileRef)) -> Model -> Element.Element Msg
view resolveTrack model =
    let
        playbackBarAttribs =
            [ Element.height <| Element.px 54
            , Element.spacing 5
            , Element.width Element.fill
            , Element.Background.color <| Color.playerGrey
            ]
    in
        Element.row
         playbackBarAttribs
            <| case model of
                NoTrack ->
                        [playingMarquee "not playing"]
                Playing q ->
                    case resolveTrack (List.Zipper.current q) of
                        Ok (data, ref) -> viewPlayer q True ref
                        Err err -> [playingMarquee err, viewQueue q]
                Paused q ->
                    case resolveTrack (List.Zipper.current q) of
                        Ok (data, ref) -> viewPlayer q False ref
                        Err err -> [playingMarquee err, viewQueue q]
                Ended q -> [playingMarquee "Playlist ended", viewQueue q]

playingMarquee txt =
    Element.el
        marqueeStyles
        <| Element.el [Element.centerY] <| Element.html (Html.node "marquee" [] [Html.text txt])
-- make this the title bar of the application
draggable =
    Element.htmlAttribute <| Html.Attributes.style "-webkit-app-region" "drag"

marqueeStyles =
    [ draggable
    , Element.height Element.fill
    , Element.width (Element.fillPortion 1 |> Element.minimum 150)
    , Element.Font.color Color.blue
    ]

viewPlayer : Queue -> Bool -> FileSystem.FileRef -> List (Element.Element Msg)
viewPlayer q isPlaying fileRef =
     [ playingMarquee fileRef.name
     , Element.el
        [Element.width (Element.fillPortion 3 |> Element.minimum 150)]
        (player isPlaying fileRef)
     , viewQueue q
     ]

viewQueue : Queue -> Element.Element Msg
viewQueue =
    List.Zipper.after
    >> List.length
    >> String.fromInt
    >> Element.text
    >> Element.el [Element.padding 40]

player : Bool -> FileSystem.FileRef -> Element.Element Msg
player isPlaying {path, name} =
    let
        fileUri =
            "file://" ++ (String.split "/" path |> List.map Url.percentEncode |> String.join "/")
        audioSrc = Html.Attributes.attribute "src"  fileUri
        attribs =
            [ audioSrc
            , Html.Attributes.type_ "audio/wav"
            , Html.Attributes.controls True
            , Html.Attributes.style "width" "auto"
            , Html.Attributes.attribute "playing" (if isPlaying then "true" else "false")
            , Html.Events.on "play" (Decode.succeed PlayClicked)
            , Html.Events.on "pause" (Decode.succeed PauseClicked)
            , Html.Events.on "end" (Decode.succeed SongEnded)
            ]
        a = Html.node
            "audio-player"
            attribs
            []
            |> Element.html
            |> Element.el [Element.width Element.fill]
    in
        a

