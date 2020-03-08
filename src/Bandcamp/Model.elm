module Bandcamp.Model exposing (..)
import Dict
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData
import Time
import FileSystem

initDownload = RequestingAssetUrl

get_download (PurchaseId item_id) model =
    Dict.get item_id model

waitingDownload = Downloading Waiting
initModel : Model
initModel =
    Model
        RemoteData.NotAsked
        Nothing
        Dict.empty

type alias PurchaseId_encoded = Int

wrapPurchaseId : (PurchaseId_encoded, a) -> (PurchaseId, a)
wrapPurchaseId = Tuple.mapFirst PurchaseId

type alias Date = Time.Posix

encodeDate = Time.posixToMillis >> Encode.int
decodeDate = Decode.int |> Decode.map Time.millisToPosix

type alias Track = {title : String, number : Int}
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

-- [decgen-start]
type alias MaybeLibrary = Maybe Library
type alias Model =
    { library : RemoteLibrary
    , cookie : Maybe Cookie
    , downloads : Downloads
    }

type alias Library =
    { download_urls : Dict.Dict String String
    , purchases : Dict.Dict String Purchase
    }

type alias LoadedModel =
    { library : Library
    , cookie : Maybe Cookie
    }
type alias Purchase =
    { title: String
    , artist : String
    , artwork: Int
    , item_id : PurchaseId
    }
type Cookie = Cookie String

type alias Downloads =
    Dict.Dict
        Int
        Download

type Download =
    RequestingFormatUrl
    | RequestingAssetUrl
    | Downloading DownloadStatus
    | Unzipping
    | Scanning
    | Completed (List FileSystem.FileRef)
    | Error

type DownloadStatus = Waiting | InProgress DownloadProgress
{-| @@TODO - make this an opaque type -}
type PurchaseId = PurchaseId Int

{-| in pct -}
type alias DownloadProgress = Int

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeCookie =
   Decode.map Cookie Decode.string

decodeDictStringPurchase =
   let
      decodeDictStringPurchaseTuple =
         Decode.map2
            (\a1 a2 -> (a1, a2))
               ( Decode.field "A1" Decode.string )
               ( Decode.field "A2" decodePurchase )
   in
      Decode.map Dict.fromList (Decode.list decodeDictStringPurchaseTuple)

decodeDictStringString =
   let
      decodeDictStringStringTuple =
         Decode.map2
            (\a1 a2 -> (a1, a2))
               ( Decode.field "A1" Decode.string )
               ( Decode.field "A2" Decode.string )
   in
      Decode.map Dict.fromList (Decode.list decodeDictStringStringTuple)

decodeDownload =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeDownloadHelp

decodeDownloadHelp constructor =
   case constructor of
      "RequestingFormatUrl" ->
         Decode.succeed RequestingFormatUrl
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
         Decode.fail <| "Unknown constructor for type Download: " ++ other

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
   let
      decodeDownloadsTuple =
         Decode.map2
            (\a1 a2 -> (a1, a2))
               ( Decode.field "A1" Decode.int )
               ( Decode.field "A2" decodeDownload )
   in
      Decode.map Dict.fromList (Decode.list decodeDownloadsTuple)

decodeLibrary =
   Decode.map2
      Library
         ( Decode.field "download_urls" decodeDictStringString )
         ( Decode.field "purchases" decodeDictStringPurchase )

decodeLoadedModel =
   Decode.map2
      LoadedModel
         ( Decode.field "library" decodeLibrary )
         ( Decode.field "cookie" (Decode.maybe decodeCookie) )

decodeMaybeLibrary =
   Decode.maybe decodeLibrary

decodeModel =
   Decode.map3
      Model
         ( Decode.field "library" decodeRemoteLibrary )
         ( Decode.field "cookie" (Decode.maybe decodeCookie) )
         ( Decode.field "downloads" decodeDownloads )

decodePurchase =
   Decode.map4
      Purchase
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "artwork" Decode.int )
         ( Decode.field "item_id" decodePurchaseId )

decodePurchaseId =
   Decode.map PurchaseId Decode.int

encodeCookie (Cookie a1) =
   Encode.string a1

encodeDictStringPurchase a =
   let
      encodeDictStringPurchaseTuple (a1,a2) =
         Encode.object
            [ ("A1", Encode.string a1)
            , ("A2", encodePurchase a2) ]
   in
      (Encode.list encodeDictStringPurchaseTuple) (Dict.toList a)

encodeDictStringString a =
   let
      encodeDictStringStringTuple (a1,a2) =
         Encode.object
            [ ("A1", Encode.string a1)
            , ("A2", Encode.string a2) ]
   in
      (Encode.list encodeDictStringStringTuple) (Dict.toList a)

encodeDownload a =
   case a of
      RequestingFormatUrl ->
         Encode.object
            [ ("Constructor", Encode.string "RequestingFormatUrl")
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
            , ("A1", (Encode.list FileSystem.encodeFileRef) a1)
            ]
      Error ->
         Encode.object
            [ ("Constructor", Encode.string "Error")
            ]

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
   let
      encodeDownloadsTuple (a1,a2) =
         Encode.object
            [ ("A1", Encode.int a1)
            , ("A2", encodeDownload a2) ]
   in
      (Encode.list encodeDownloadsTuple) (Dict.toList a)

encodeLibrary a =
   Encode.object
      [ ("download_urls", encodeDictStringString a.download_urls)
      , ("purchases", encodeDictStringPurchase a.purchases)
      ]

encodeLoadedModel a =
   Encode.object
      [ ("library", encodeLibrary a.library)
      , ("cookie", encodeMaybeCookie a.cookie)
      ]

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
      ]

encodePurchase a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("artwork", Encode.int a.artwork)
      , ("item_id", encodePurchaseId a.item_id)
      ]

encodePurchaseId (PurchaseId a1) =
   Encode.int a1 
-- [decgen-end]







