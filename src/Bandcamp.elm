port module Bandcamp exposing (..)

import Element
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Html
import RemoteData
import Time
import Dict
import Element.Input
import Element.Font

type Msg =
    CookieRetrieved Cookie
  | DataRetrieved (Result Decode.Error Library)
  | DownloadButtonClicked String

browser : Model -> Element.Element Msg
browser model =
    case model of
        NoCookie -> authElement
        Loading cookie -> Element.paragraph [Element.padding 50, Element.Font.center] [Element.text "Loading..."]
        Loaded cookie library ->
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
                    Dict.toList library.purchases
                    |> List.map (viewPurchase library)
            in
                Element.wrappedRow attribs content

viewPurchase : Library -> (String, Purchase) -> Element.Element Msg
viewPurchase library (id, {title, artist, artwork}) =
    let
        downloadUrl = Dict.get id library.download_urls
        imgSrc =
            "https://f4.bcbits.com/img/a"
            ++ (String.fromInt artwork)
            ++ "_16.jpg"
        viewDownloadButton =
            Element.Input.button
                []
                { label = Element.text "download"
                , onPress = Just <| DownloadButtonClicked id
                }
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
    case model of
        Loading (Cookie cookie) -> fetchLatestLibrary cookie
        Loaded (Cookie cookie) library -> fetchLatestLibrary cookie
        NoCookie -> Cmd.none

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
            Decode.map3 Purchase
                (Decode.field "item_title" Decode.string)
                (Decode.field "band_name" Decode.string)
                (Decode.field "item_art_id" Decode.int)

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
    NoCookie

initLibrary =
    Library
        Dict.empty
        Dict.empty
type alias Date = Time.Posix

encodeDate = Time.posixToMillis >> Encode.int
decodeDate = Decode.int |> Decode.map Time.millisToPosix

type alias Track = {title : String, number : Int}

-- [decgen-start]
type Model =
    NoCookie
    | Loading Cookie
    | Loaded Cookie Library


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

decodeModel =
   Decode.field "Constructor" Decode.string |> Decode.andThen decodeModelHelp

decodeModelHelp constructor =
   case constructor of
      "NoCookie" ->
         Decode.succeed NoCookie
      "Loading" ->
         Decode.map
            Loading
               ( Decode.field "A1" decodeCookie )
      "Loaded" ->
         Decode.map2
            Loaded
               ( Decode.field "A1" decodeCookie )
               ( Decode.field "A2" decodeLibrary )
      other->
         Decode.fail <| "Unknown constructor for type Model: " ++ other

decodePurchase =
   Decode.map3
      Purchase
         ( Decode.field "title" Decode.string )
         ( Decode.field "artist" Decode.string )
         ( Decode.field "artwork" Decode.int )

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

encodeModel a =
   case a of
      NoCookie ->
         Encode.object
            [ ("Constructor", Encode.string "NoCookie")
            ]
      Loading a1->
         Encode.object
            [ ("Constructor", Encode.string "Loading")
            , ("A1", encodeCookie a1)
            ]
      Loaded a1 a2->
         Encode.object
            [ ("Constructor", Encode.string "Loaded")
            , ("A1", encodeCookie a1)
            , ("A2", encodeLibrary a2)
            ]

encodePurchase a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("artwork", Encode.int a.artwork)
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
            |> Debug.log "blob"
            |> always (Decode.fail "get blob först")
    in
        Decode.string
        |> Decode.andThen getBlob

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case model of
        NoCookie -> case msg of
            CookieRetrieved (Cookie c) -> (Loading (Cookie c), fetchLatestLibrary c)
            _ -> (model, Cmd.none)
        Loading cookie -> case msg of
            DataRetrieved res ->
                case Debug.log "res" res of
                    Ok library ->
                        (Loaded cookie library
                        , Cmd.none
                        )
                    Err e -> (model, Cmd.none)
            _ -> (model, Cmd.none)
        Loaded cookie library -> case msg of
            DownloadButtonClicked bandcampPurchaseId -> Debug.todo "download"
            _ -> (model, Cmd.none)
