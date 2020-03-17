port module Bandcamp.SimpleDownloader exposing
    ( Msg(..)
    , subscriptions
    , update
    , view
    , Downloads
    , encodeDownloads
    , decodeDownloads
    , getLocalUrl
    )

import Dict
import Html
import Html.Events
import Json.Encode as Encode
import Json.Decode as Decode
import Track

port bandcamp_simpleDownloader_out_request : RequestPayload -> Cmd msg
port bandcamp_simpleDownloader_in_progress : (ProgressPayload -> msg) -> Sub msg
port bandcamp_simpleDownloader_in_complete : (Track.Id -> msg) -> Sub msg

subscriptions =
    Sub.batch
        [
        bandcamp_simpleDownloader_in_progress Progress
        , bandcamp_simpleDownloader_in_complete Complete
        ]

getLocalUrl : String -> Track.Id -> Downloads -> Maybe Url
getLocalUrl rootUrl id downloads =
    case Dict.get id downloads of
        Just Completed -> Just <| rootUrl ++ "/bandcamp-downloads/tracks/" ++ id ++ ".mp3"
        _ -> Nothing

{-| Inline view to display inside a track table row -}
view : String -> Track.Id -> Url -> Downloads -> Html.Html Msg
view cookie id url downloads =
    case Dict.get id downloads of
        Nothing -> Html.div [Html.Events.onClick (Request {track_id= id, url = url, cookie = cookie})] [Html.text ">>load"]
        Just Completed -> Html.text "loaded."
        Just (Loading progress) -> Html.text ("loading: " ++ String.fromInt progress)
        Just Requesting -> Html.text "requesting"


update : Msg -> Downloads -> (Downloads, Cmd Msg)
update msg downloads =
    case msg of
        Request payload -> (Dict.insert payload.track_id Requesting downloads, bandcamp_simpleDownloader_out_request payload)
        Progress payload -> (Dict.insert payload.track_id (Loading payload.percent) downloads, Cmd.none)
        Complete track_id -> (Dict.insert track_id Completed downloads, Cmd.none)

-- [generator-start]
{-| Simple process, we do not assume the process can fail for now -}
type Msg =
    Request RequestPayload
    | Progress ProgressPayload
    | Complete Track.Id

type Status =
    Requesting
    | Loading Int
    | Completed

type alias Downloads = Dict.Dict Track.Id Status

type alias Url = String
type alias RequestPayload = {track_id: Track.Id, url: Url, cookie : String}
type alias ProgressPayload = {track_id: Track.Id, percent: Int}

-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeDownloads =
   let
      decodeDownloadsTuple =
         Decode.map2
            (\a1 a2 -> (a1, a2))
               ( Decode.field "A1" Track.decodeId )
               ( Decode.field "A2" decodeStatus )
   in
      Decode.map Dict.fromList (Decode.list decodeDownloadsTuple)

decodeMsg =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeMsgHelp

decodeMsgHelp constructor =
   case constructor of
      "Request" ->
         Decode.map
            Request
               ( Decode.field "A1" decodeRequestPayload )
      "Progress" ->
         Decode.map
            Progress
               ( Decode.field "A1" decodeProgressPayload )
      "Complete" ->
         Decode.map
            Complete
               ( Decode.field "A1" Track.decodeId )
      other->
         Decode.fail <| "Unknown constructor for type Msg: " ++ other

decodeProgressPayload =
   Decode.map2
      ProgressPayload
         ( Decode.field "track_id" Track.decodeId )
         ( Decode.field "percent" Decode.int )

decodeRequestPayload =
   Decode.map3
      RequestPayload
         ( Decode.field "track_id" Track.decodeId )
         ( Decode.field "url" decodeUrl )
         ( Decode.field "cookie" Decode.string )

decodeStatus =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeStatusHelp

decodeStatusHelp constructor =
   case constructor of
      "Requesting" ->
         Decode.succeed Requesting
      "Loading" ->
         Decode.map
            Loading
               ( Decode.field "A1" Decode.int )
      "Completed" ->
         Decode.succeed Completed
      other->
         Decode.fail <| "Unknown constructor for type Status: " ++ other

decodeUrl =
   Decode.string

encodeDownloads a =
   let
      encodeDownloadsTuple (a1,a2) =
         Encode.object
            [ ("A1", Track.encodeId a1)
            , ("A2", encodeStatus a2) ]
   in
      (Encode.list encodeDownloadsTuple) (Dict.toList a)

encodeMsg a =
   case a of
      Request a1->
         Encode.object
            [ ("Constructor", Encode.string "Request")
            , ("A1", encodeRequestPayload a1)
            ]
      Progress a1->
         Encode.object
            [ ("Constructor", Encode.string "Progress")
            , ("A1", encodeProgressPayload a1)
            ]
      Complete a1->
         Encode.object
            [ ("Constructor", Encode.string "Complete")
            , ("A1", Track.encodeId a1)
            ]

encodeProgressPayload a =
   Encode.object
      [ ("track_id", Track.encodeId a.track_id)
      , ("percent", Encode.int a.percent)
      ]

encodeRequestPayload a =
   Encode.object
      [ ("track_id", Track.encodeId a.track_id)
      , ("url", encodeUrl a.url)
      , ("cookie", Encode.string a.cookie)
      ]

encodeStatus a =
   case a of
      Requesting ->
         Encode.object
            [ ("Constructor", Encode.string "Requesting")
            ]
      Loading a1->
         Encode.object
            [ ("Constructor", Encode.string "Loading")
            , ("A1", Encode.int a1)
            ]
      Completed ->
         Encode.object
            [ ("Constructor", Encode.string "Completed")
            ]

encodeUrl a =
   Encode.string a 
-- [generator-end]
