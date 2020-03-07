port module Bandcamp exposing (..)

import Element
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Html
import RemoteData
import Time
import Dict

browser : Model -> Element.Element msg
browser model =
    Dict.toList model.purchases
    |> List.map viewPurchase
    |> Element.wrappedRow [Element.spacing 50, Element.padding 50]

viewPurchase : (String, Purchase) -> Element.Element msg
viewPurchase (id, {title, artist, artwork}) =
    let
        imgSrc =
            "https://f4.bcbits.com/img/a"
            ++ (String.fromInt artwork)
            ++ "_16.jpg"
    in
    Element.column
        [Element.width (Element.px 300), Element.spacing 10]
        [
            Element.image
                [Element.height (Element.px 300), Element.width (Element.px 300)]
                {src = imgSrc, description = title}
          , Element.column
            [ Element.spacing 10 ]
            [ Element.paragraph [] [Element.text title]
            , Element.text artist
            ]
        ]


init (Cookie cookie) = bandcamp_init_request cookie

port bandcamp_init_request : String -> Cmd msg
port bandcamp_library_retrieved : (Decode.Value -> msg) -> Sub msg


extractModelFromBlob : Decode.Decoder Model
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
            Model
            extractDownloadUrls
            extractPurchases

initModel : Model
initModel =
    Model
        Dict.empty
        Dict.empty

type alias Date = Time.Posix

encodeDate = Time.posixToMillis >> Encode.int
decodeDate = Decode.int |> Decode.map Time.millisToPosix

type alias Track = {title : String, number : Int}

-- [decgen-start]

type alias Model =
    { download_urls : Dict.Dict String String
    , purchases : Dict.Dict String Purchase
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

decodeModel =
   Decode.map2
      Model
         ( Decode.field "download_urls" decodeDictStringString )
         ( Decode.field "purchases" decodeDictStringPurchase )

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

encodeModel a =
   Encode.object
      [ ("download_urls", encodeDictStringString a.download_urls)
      , ("purchases", encodeDictStringPurchase a.purchases)
      ]

encodePurchase a =
   Encode.object
      [ ("title", Encode.string a.title)
      , ("artist", Encode.string a.artist)
      , ("artwork", Encode.int a.artwork)
      ] 
-- [decgen-end]


{-| Launch bandcamp/login inside an iframe and extract the cookie when the user was authed successfully -}
authElement : Element.Element Cookie
authElement =
    let
        parseCookie cookieString =
            if String.isEmpty cookieString
                then Decode.fail "cookie can not be an empty string"
                else Decode.succeed (Cookie cookieString)

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

statusIndicator : Maybe Cookie -> Element.Element Cookie
statusIndicator cookie =
    let
        loggedIn = Element.el [Element.padding 10] <| Element.text "BC OK"
        authing =
            Element.el [
                Element.inFront authElement
                , Element.alignTop
                , Element.alignRight
                , Element.moveLeft 300
            ] Element.none
    in
    case cookie of
        Just _ -> loggedIn
        Nothing -> authing
