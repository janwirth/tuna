port module Bandcamp exposing (..)

import Element
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Html
import RemoteData exposing (WebData)
import Time
import Dict
import Element.Input
import Element.Font
import Element.Background
import Color

type Msg =
    CookieRetrieved Cookie
  | DataRetrieved (Result Decode.Error Library)
  | DownloadButtonClicked Int

to_download_id : Int -> String
to_download_id id =
    "p" ++ String.fromInt id
browser : Model -> Element.Element Msg
browser model =
    let
        loading =
            Element.paragraph
                [Element.padding 50, Element.Font.center]
                [Element.text "Loading..."]

        viewLib lib =
            let
                attribs =
                    [ Element.height Element.fill
                    , Element.width Element.fill
                    , Element.clipY
                    , Element.scrollbarY
                    , Element.spacing 50
                    , Element.padding 50
                    ]
                content =
                    Dict.toList lib.purchases
                    |> List.map (viewPurchase model.downloads lib)
            in
                Element.wrappedRow attribs content

    in case model.cookie of
        Nothing -> authElement
        Just _ -> case model.library of
            RemoteData.NotAsked -> loading
            RemoteData.Failure e -> Element.text e
            RemoteData.Loading -> loading
            RemoteData.Success library ->
                viewLib library

viewPurchase : Downloads -> Library -> (String, Purchase) -> Element.Element Msg
viewPurchase downloads library (id, {title, artist, artwork, item_id}) =
    let
        download_id = to_download_id item_id
        download_url =
            Dict.get download_id library.download_urls
        imgSrc =
            "https://f4.bcbits.com/img/a"
            ++ (String.fromInt artwork)
            ++ "_16.jpg"
        viewLabel =
            case Dict.get item_id downloads of
                Nothing -> Element.text "download"
                Just (Waiting) -> Element.text "waiting"
                Just (Downloading pct) -> Element.text (">> " ++ String.fromInt pct)
                Just (Completed) -> Element.text "Downloaded"
                Just (Error) -> Element.text "Error"

        viewDownloadButton =
            case download_url of
                Just u ->
                    Element.Input.button
                        [Element.padding 10, Element.Background.color Color.playerGrey]
                        { label = viewLabel
                        , onPress = Just <| DownloadButtonClicked item_id
                        }
                Nothing ->
                    Element.text "no download available"
        viewInfo =
            Element.column
                [ Element.spacing 10 ]
                [ Element.paragraph [] [Element.text title]
                , Element.text artist
                ]

        viewArtwork =
            Element.image
                [Element.height (Element.px 300), Element.width (Element.px 300)]
                {src = imgSrc, description = title}
    in
    Element.column
        [Element.width (Element.px 300), Element.spacing 10]
        [
            viewArtwork
          , viewInfo
          , viewDownloadButton
        ]

initCmd : Model -> Cmd Msg
initCmd model =
    case model.cookie of
        Just (Cookie cookie) -> fetchLatestLibrary cookie
        Nothing -> Cmd.none

fetchLatestLibrary : String -> Cmd Msg
fetchLatestLibrary cookie =
    bandcamp_init_request cookie

port bandcamp_init_request : String -> Cmd msg
port bandcamp_library_retrieved : (Decode.Value -> msg) -> Sub msg


extractModelFromBlob : Decode.Decoder Library
extractModelFromBlob =
    let
        extractPurchases : Decode.Decoder (Dict.Dict String Purchase)
        extractPurchases =
            Decode.at ["item_cache", "collection"] (Decode.dict extractPurchase)

        extractPurchase : Decode.Decoder Purchase
        extractPurchase =
            Decode.map4 Purchase
                (Decode.field "item_title" Decode.string)
                (Decode.field "band_name" Decode.string)
                (Decode.field "item_art_id" Decode.int)
                (Decode.field "sale_item_id" Decode.int)

        extractDownloadUrls : Decode.Decoder (Dict.Dict String String)
        extractDownloadUrls =
            Decode.at
                ["collection_data", "redownload_urls"]
                (Decode.dict Decode.string)
    in
        Decode.map2
            Library
            extractDownloadUrls
            extractPurchases

initModel : Model
initModel =
    Model
        RemoteData.NotAsked
        Nothing
        Dict.empty

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

type alias Downloads = Dict.Dict Int Download
type Download =
    Waiting
    | Downloading Int
    | Completed
    | Error

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
    , item_id : Int
    }
type Cookie = Cookie String

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
      "Waiting" ->
         Decode.succeed Waiting
      "Downloading" ->
         Decode.map
            Downloading
               ( Decode.field "A1" Decode.int )
      "Completed" ->
         Decode.succeed Completed
      "Error" ->
         Decode.succeed Error
      other->
         Decode.fail <| "Unknown constructor for type Download: " ++ other

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
         ( Decode.field "item_id" Decode.int )

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
      Waiting ->
         Encode.object
            [ ("Constructor", Encode.string "Waiting")
            ]
      Downloading a1->
         Encode.object
            [ ("Constructor", Encode.string "Downloading")
            , ("A1", Encode.int a1)
            ]
      Completed ->
         Encode.object
            [ ("Constructor", Encode.string "Completed")
            ]
      Error ->
         Encode.object
            [ ("Constructor", Encode.string "Error")
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
      , ("item_id", Encode.int a.item_id)
      ] 
-- [decgen-end]


{-| Launch bandcamp/login inside an iframe and extract the cookie when the user was authed successfully -}
authElement : Element.Element Msg
authElement =
    let
        parseCookie cookieString =
            if String.isEmpty cookieString
                then Decode.fail "cookie can not be an empty string"
                else Decode.succeed (CookieRetrieved <| Cookie cookieString)

        listener = Html.Events.on "cookieretrieve" readCookie
        readCookie =
            Decode.at ["detail", "cookie"] Decode.string
            |> Decode.andThen parseCookie
    in
        Element.html (Html.node "bandcamp-auth" [listener] [])


extractPageData : Decode.Decoder Decode.Value
extractPageData =
    let
        getBlob html =
            html
            |> always (Decode.fail "get blob först")
    in
        Decode.string
        |> Decode.andThen getBlob

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        CookieRetrieved (Cookie c) ->
            ({model | cookie = Just (Cookie c)}
            , fetchLatestLibrary c)
        DataRetrieved res ->
            case res of
                Ok newLibrary ->
                    ({model | library = RemoteData.succeed newLibrary}
                    , Cmd.none
                    )
                Err e -> (model, Cmd.none)
        DownloadButtonClicked id ->
            let
                return =
                    model.library
                    |> RemoteData.toMaybe
                    |> Maybe.andThen (\{download_urls} -> Dict.get (to_download_id id) download_urls)
                    |> Maybe.map2 startdownload model.cookie
                    |> Maybe.withDefault (model, Cmd.none)
                startdownload (Cookie cookie) download_url =
                    let
                        downloadCmd = bandcamp_download_request (cookie, id, download_url)
                        mdl =
                            { model
                            | downloads = Dict.insert id Waiting model.downloads
                            }
                    in
                        (mdl, downloadCmd)
            in
                return

port bandcamp_download_request : (String, Int, String) -> Cmd msg


