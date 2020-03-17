module Bandcamp.Model exposing (..)
import Dict
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData
import Time
import FileSystem
import Bandcamp.Id
import Bandcamp.SimpleDownloader

initDownload = RequestingAssetUrl

waitingDownload = Downloading Waiting

initModel : Model
initModel =
    Model
        RemoteData.NotAsked
        Nothing
        Bandcamp.Id.emptyDict_
        Dict.empty

getItemById : Bandcamp.Id.Id -> Model -> Maybe Purchase
getItemById id {library} =
    RemoteData.toMaybe library
    |> Maybe.andThen (.purchases >> Bandcamp.Id.getBy id)




type alias DownloadsSummary = {error: Bool, status: DownloadsSummaryStatus}
type DownloadsSummaryStatus = SomeLoading Int Int | AllDone
summarizeDownloads : Downloads -> DownloadsSummary
summarizeDownloads d =
    let
        dls = Bandcamp.Id.dictToList d
        dlsInProgress =
            dls
            |> List.filterMap
                (\(_, dl) -> case dl of
                    Downloading (InProgress pct) -> Just pct
                    Downloading Waiting -> Just 0
                    _ -> Nothing
                )
        avg : List Int -> Int
        avg l =
            (List.sum l) // (List.length l)

        status = if List.isEmpty dlsInProgress then AllDone else SomeLoading (avg dlsInProgress) (List.length dlsInProgress)
        hasError =
            dls
            |> List.filter
                (\(_, dl) -> case dl of
                    Error -> False
                    _ -> True
                )
            |> List.isEmpty
    in
        DownloadsSummary hasError status

type alias Download = EncodeableDownload


{-| Downloads should be reset on load if not completed -}
decodeDownload : Decode.Decoder Download
decodeDownload =
   decodeEncodeableDownload
   {- Comment this to debug / freeze download statuses between reloads -}
   |> Decode.map
   (\dl -> case dl of
       Completed s -> Completed s
       Error -> Error
       _ -> NotAsked
   )

encodeDownload = encodeEncodeableDownload

type alias Date = Time.Posix

encodeDate = Time.posixToMillis >> Encode.int
decodeDate = Decode.int |> Decode.map Time.millisToPosix

type alias RemoteLibrary =
    RemoteData.RemoteData String Library

decodeRemoteLibrary : Decode.Decoder RemoteLibrary
decodeRemoteLibrary =
        decodeMaybeLibrary
        |> Decode.map (RemoteData.fromMaybe "Stored library not found")

encodeRemoteLibrary : RemoteLibrary -> Encode.Value
encodeRemoteLibrary =
    RemoteData.toMaybe
    >> encodeMaybeLibrary

-- [generator-start]

type alias MaybeLibrary = Maybe Library
type alias Model =
    { library : RemoteLibrary
    , cookie : Maybe Cookie
    , downloads : Downloads
    , simpleDownloads : Bandcamp.SimpleDownloader.Downloads
    }

type alias Library =
    { download_urls : Bandcamp.Id.Dict_ String
    , purchases : Bandcamp.Id.Dict_ Purchase
    }

type alias LoadedModel =
    { library : Library
    , cookie : Maybe Cookie
    }
type alias Purchase =
    { title: String
    , artist : String
    , artwork: Int
    , item_id : Bandcamp.Id.Id
    , sale_item_id : Maybe Bandcamp.Id.Id
    , purchase_type : PurchaseType
    , tracks : List TrackInfo
    }

type alias TrackInfo =
    { title : String
    , artist: String
    , playback_url: String
    , id : String
    }

type PurchaseType = Album | Track

type Cookie = Cookie String

type alias Downloads = Bandcamp.Id.Dict_ Download

type EncodeableDownload =
    NotAsked
    | RequestingAssetUrl
    | Downloading DownloadStatus
    | Unzipping
    | Scanning
    | Completed (List FileSystem.FileRef)
    | Error

type DownloadStatus = Waiting | InProgress DownloadProgress

{-| in pct -}
type alias DownloadProgress = Int


-- [generator-generated-start] -- DO NOT MODIFY or remove this line
decodeCookie =
   Decode.map Cookie Decode.string

decodeDownloadProgress =
   Decode.int

decodeDownloadStatus =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeDownloadStatusHelp

decodeDownloadStatusHelp constructor =
   case constructor of
      "Waiting" ->
         Decode.succeed Waiting
      "InProgress" ->
         Decode.map
            InProgress
               ( Decode.field "A1" decodeDownloadProgress )
      other->
         Decode.fail <| "Unknown constructor for type DownloadStatus: " ++ other

decodeDownloads =
   Bandcamp.Id.decodeDict_ decodeDownload

decodeEncodeableDownload =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeEncodeableDownloadHelp

decodeEncodeableDownloadHelp constructor =
   case constructor of
      "NotAsked" ->
         Decode.succeed NotAsked
      "RequestingAssetUrl" ->
         Decode.succeed RequestingAssetUrl
      "Downloading" ->
         Decode.map
            Downloading
               ( Decode.field "A1" decodeDownloadStatus )
      "Unzipping" ->
         Decode.succeed Unzipping
      "Scanning" ->
         Decode.succeed Scanning
      "Completed" ->
         Decode.map
            Completed
               ( Decode.field "A1" (Decode.list FileSystem.decodeFileRef) )
      "Error" ->
         Decode.succeed Error
      other->
         Decode.fail <| "Unknown constructor for type EncodeableDownload: " ++ other

decodeLibrary =
   Decode.map2
      Library
         ( Decode.field "download_urls" ((Bandcamp.Id.decodeDict_ Decode.string)) )
         ( Decode.field "purchases" ((Bandcamp.Id.decodeDict_ decodePurchase)) )

decodeLoadedModel =
   Decode.map2
      LoadedModel
         ( Decode.field "library" decodeLibrary )
         ( Decode.field "cookie" (Decode.maybe decodeCookie) )

decodeMaybeLibrary =
   Decode.maybe decodeLibrary

decodeModel =
   Decode.map4
      Model
         ( Decode.field "library" decodeRemoteLibrary )
         ( Decode.field "cookie" (Decode.maybe decodeCookie) )
         ( Decode.field "downloads" decodeDownloads )
         ( Decode.field "simpleDownloads" Bandcamp.SimpleDownloader.decodeDownloads )

decodePurchase =
   Decode.map7
      Purchase
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "artwork" Decode.int )
         ( Decode.field "item_id" Bandcamp.Id.decodeId )
         ( Decode.field "sale_item_id" (Decode.maybe Bandcamp.Id.decodeId) )
         ( Decode.field "purchase_type" decodePurchaseType )
         ( Decode.field "tracks" (Decode.list decodeTrackInfo) )

decodePurchaseType =
   let
      recover x =
         case x of
            "Album"->
               Decode.succeed Album
            "Track"->
               Decode.succeed Track
            other->
               Decode.fail <| "Unknown constructor for type PurchaseType: " ++ other
   in
      Decode.string |> Decode.andThen recover

decodeTrackInfo =
   Decode.map4
      TrackInfo
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "playback_url" Decode.string )
         ( Decode.field "id" Decode.string )

encodeCookie (Cookie a1) =
   Encode.string a1

encodeDownloadProgress a =
   Encode.int a

encodeDownloadStatus a =
   case a of
      Waiting ->
         Encode.object
            [ ("Constructor", Encode.string "Waiting")
            ]
      InProgress a1->
         Encode.object
            [ ("Constructor", Encode.string "InProgress")
            , ("A1", encodeDownloadProgress a1)
            ]

encodeDownloads a =
   Bandcamp.Id.encodeDict_ encodeDownload a

encodeEncodeableDownload a =
   case a of
      NotAsked ->
         Encode.object
            [ ("Constructor", Encode.string "NotAsked")
            ]
      RequestingAssetUrl ->
         Encode.object
            [ ("Constructor", Encode.string "RequestingAssetUrl")
            ]
      Downloading a1->
         Encode.object
            [ ("Constructor", Encode.string "Downloading")
            , ("A1", encodeDownloadStatus a1)
            ]
      Unzipping ->
         Encode.object
            [ ("Constructor", Encode.string "Unzipping")
            ]
      Scanning ->
         Encode.object
            [ ("Constructor", Encode.string "Scanning")
            ]
      Completed a1->
         Encode.object
            [ ("Constructor", Encode.string "Completed")
            , ("A1", Encode.list FileSystem.encodeFileRef a1)
            ]
      Error ->
         Encode.object
            [ ("Constructor", Encode.string "Error")
            ]

encodeLibrary a =
   Encode.object
      [ ("download_urls", ((Bandcamp.Id.encodeDict_ Encode.string)) a.download_urls)
      , ("purchases", ((Bandcamp.Id.encodeDict_ encodePurchase)) a.purchases)
      ]

encodeLoadedModel a =
   Encode.object
      [ ("library", encodeLibrary a.library)
      , ("cookie", encodeMaybeCookie a.cookie)
      ]

encodeMaybeBandcamp_Id_Id a =
   case a of
      Just b->
         Bandcamp.Id.encodeId b
      Nothing->
         Encode.null

encodeMaybeCookie a =
   case a of
      Just b->
         encodeCookie b
      Nothing->
         Encode.null

encodeMaybeLibrary a =
   case a of
      Just b->
         encodeLibrary b
      Nothing->
         Encode.null

encodeModel a =
   Encode.object
      [ ("library", encodeRemoteLibrary a.library)
      , ("cookie", encodeMaybeCookie a.cookie)
      , ("downloads", encodeDownloads a.downloads)
      , ("simpleDownloads", Bandcamp.SimpleDownloader.encodeDownloads a.simpleDownloads)
      ]

encodePurchase a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("artwork", Encode.int a.artwork)
      , ("item_id", Bandcamp.Id.encodeId a.item_id)
      , ("sale_item_id", encodeMaybeBandcamp_Id_Id a.sale_item_id)
      , ("purchase_type", encodePurchaseType a.purchase_type)
      , ("tracks", (Encode.list encodeTrackInfo) a.tracks)
      ]

encodePurchaseType a =
   case a of
      Album ->
         Encode.string "Album"
      Track ->
         Encode.string "Track"

encodeTrackInfo a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("playback_url", Encode.string a.playback_url)
      , ("id", Encode.string a.id)
      ] 
-- [generator-end]
