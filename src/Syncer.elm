port module Syncer exposing
    (init
    , view
    , Model
    , decodeModel
    , encodeModel
    , Msg
    , update
    , MissingItems
    , subscriptions
    , FilesToCopy
    )

import Json.Decode as Decode
import Json.Encode as Encode
import Element
import Html.Events
import Html
import Color
import Element.Background
import Track
import Bandcamp.Model
import Element.Input

port syncer_out_prepare_assets : PreparePayload -> Cmd msg
port syncer_out_copy : {files: FilesToCopy, to : Directory} -> Cmd msg
port syncer_in_copy_one_complete : (() -> msg) -> Sub msg

subscriptions : Sub Msg
subscriptions = syncer_in_copy_one_complete (always CopiedOne)

type alias PreparePayload = {cookie: String, items: MissingItems}
type alias MissingItems = List {track_id : String, url: String}
type alias FilesToCopy = List {uri: String, name: String}

view : Maybe Bandcamp.Model.Cookie -> MissingItems -> FilesToCopy -> Model -> Element.Element Msg
view cookie missing paths model =
    case model of
        Syncing _ remaining -> viewProgress remaining
        Completed _ -> viewButton cookie missing paths model
        NotAsked -> viewButton cookie missing paths model

viewProgress : Int -> Element.Element Msg
viewProgress remaining = Element.text <| "Copying: " ++ String.fromInt remaining

viewButton : Maybe Bandcamp.Model.Cookie -> MissingItems -> FilesToCopy -> Model -> Element.Element Msg
viewButton cookie missing files model =
    case (missing, cookie) of
        ([], _) ->
            let
                listener = Html.Events.on "choosedirectory" readDirectory
                readDirectory =
                    Decode.at ["detail", "directory"] Decode.string
                    |> Decode.map (DirectoryPicked files)
            in
                Html.node "directory-picker" [listener] [Html.text "Sync with..."]
                |> Element.html
                |> Element.el [Element.Background.color Color.playerGrey, Element.width Element.fill, Element.padding 10]
        (some, Just (Bandcamp.Model.Cookie cookie_)) ->
            let
                preparePayload = PreparePayload cookie_ some
            in
                Element.Input.button
                    []
                    {onPress = Just (FetchAll preparePayload), label = Element.text "Download visible tracks"}
        _ -> Element.none

init : Model
init = NotAsked

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case (msg, model) of
        -- init / prepare
        (FetchAll preparePayload, _) ->
            (NotAsked, syncer_out_prepare_assets preparePayload)

        (DirectoryPicked paths directory, _) ->
            (Syncing directory (List.length paths), syncer_out_copy {files = paths, to = directory})

        -- copy
        (CopiedOne, Syncing directory remaining) ->
            case remaining - 1 of
                0 ->
                    (Completed directory, Cmd.none)
                more -> (Syncing directory more, Cmd.none)
        _ -> (model, Cmd.none)


type Msg =
    FetchAll PreparePayload
    | DirectoryPicked FilesToCopy Directory
    | CopiedOne

type alias Model = Model_
decodeModel = Decode.succeed init
encodeModel _ = Encode.null
-- [generator-start]
type alias Directory = String
type Model_ =
      NotAsked
     | Syncing Directory Int -- remaining files to copy
     | Completed Directory


-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeDirectory =
   Decode.string

decodeModel_ =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeModel_Help

decodeModel_Help constructor =
   case constructor of
      "NotAsked" ->
         Decode.succeed NotAsked
      "Syncing" ->
         Decode.map2
            Syncing
               ( Decode.field "A1" decodeDirectory )
               ( Decode.field "A2" Decode.int )
      "Completed" ->
         Decode.map
            Completed
               ( Decode.field "A1" decodeDirectory )
      other->
         Decode.fail <| "Unknown constructor for type Model_: " ++ other

encodeDirectory a =
   Encode.string a

encodeModel_ a =
   case a of
      NotAsked ->
         Encode.object
            [ ("Constructor", Encode.string "NotAsked")
            ]
      Syncing a1 a2->
         Encode.object
            [ ("Constructor", Encode.string "Syncing")
            , ("A1", encodeDirectory a1)
            , ("A2", Encode.int a2)
            ]
      Completed a1->
         Encode.object
            [ ("Constructor", Encode.string "Completed")
            , ("A1", encodeDirectory a1)
            ] 
-- [generator-end]
