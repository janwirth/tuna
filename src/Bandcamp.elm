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
import Bandcamp.Downloader
import Bandcamp.Model

subscriptions : Bandcamp.Model.Model -> Sub Msg
subscriptions model =
    let
        captureBandcampLib val =
            val
            |> Decode.decodeValue extractModelFromBlob
            |> DataRetrieved
    in
        Sub.batch [
            bandcamp_in_connection_opened captureBandcampLib
          , Bandcamp.Downloader.subscriptions model.downloads
            |> Sub.map DownloaderMsg
        ]

port bandcamp_out_connection_requested : String -> Cmd msg
port bandcamp_in_connection_opened : (Decode.Value -> msg) -> Sub msg

type Msg =
    CookieRetrieved Bandcamp.Model.Cookie
  | DataRetrieved (Result Decode.Error Bandcamp.Model.Library)
  | DownloaderMsg Bandcamp.Downloader.Msg

browser : Bandcamp.Model.Model -> Element.Element Msg
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

viewPurchase : Bandcamp.Model.Downloads -> Bandcamp.Model.Library -> (String, Bandcamp.Model.Purchase) -> Element.Element Msg
viewPurchase downloads library (id, {title, artist, artwork, item_id}) =
    let
        imgSrc =
            "https://f4.bcbits.com/img/a"
            ++ (String.fromInt artwork)
            ++ "_16.jpg"
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
        viewDownloadOptions = case Dict.get (Bandcamp.Downloader.to_download_id item_id) library.download_urls of
            Just u ->
                Bandcamp.Downloader.viewDownloadButton downloads item_id
            Nothing ->
                Element.text "no download available"
    in
    Element.column
        [Element.width (Element.px 300), Element.spacing 10]
        [
            viewArtwork
          , viewInfo
          , viewDownloadOptions
        ]
        |> Element.map DownloaderMsg

initCmd : Bandcamp.Model.Model -> Cmd Msg
initCmd model =
    case model.cookie of
        Just (Bandcamp.Model.Cookie cookie) -> fetchLatestLibrary cookie
        Nothing -> Cmd.none

fetchLatestLibrary : String -> Cmd Msg
fetchLatestLibrary cookie =
    bandcamp_out_connection_requested cookie



extractModelFromBlob : Decode.Decoder Bandcamp.Model.Library
extractModelFromBlob =
    let
        extractPurchases : Decode.Decoder (Dict.Dict String Bandcamp.Model.Purchase)
        extractPurchases =
            Decode.at ["item_cache", "collection"] (Decode.dict extractPurchase)

        extractPurchase : Decode.Decoder Bandcamp.Model.Purchase
        extractPurchase =
            Decode.map4 Bandcamp.Model.Purchase
                (Decode.field "item_title" Decode.string)
                (Decode.field "band_name" Decode.string)
                (Decode.field "item_art_id" Decode.int)
                (Decode.field "sale_item_id" Decode.int |> Decode.map Bandcamp.Model.PurchaseId)

        extractDownloadUrls : Decode.Decoder (Dict.Dict String String)
        extractDownloadUrls =
            Decode.at
                ["collection_data", "redownload_urls"]
                (Decode.dict Decode.string)
    in
        Decode.map2
            Bandcamp.Model.Library
            extractDownloadUrls
            extractPurchases


{-| Launch bandcamp/login inside an iframe and extract the cookie when the user was authed successfully -}
authElement : Element.Element Msg
authElement =
    let
        parseCookie : String -> Decode.Decoder Msg
        parseCookie cookieString =
            if String.isEmpty cookieString
                then Decode.fail "cookie can not be an empty string"
                else Decode.succeed (CookieRetrieved <| Bandcamp.Model.Cookie cookieString)

        listener = Html.Events.on "cookieretrieve" readCookie
        readCookie =
            Decode.at ["detail", "cookie"] Decode.string
            |> Decode.andThen parseCookie
    in
        Element.html (Html.node "bandcamp-auth" [listener] [])

update : Msg -> Bandcamp.Model.Model -> (Bandcamp.Model.Model, Cmd Msg)
update msg model =
    case msg of
        CookieRetrieved (Bandcamp.Model.Cookie c) ->
            ({model | cookie = Just (Bandcamp.Model.Cookie c)}
            , fetchLatestLibrary c)
        DataRetrieved res ->
            case res of
                Ok newLibrary ->
                    ({model | library = RemoteData.succeed newLibrary}
                    , Cmd.none
                    )
                Err e -> (model, Cmd.none)
        DownloaderMsg msg_ ->
            let
                (mdl, cmd) = Bandcamp.Downloader.update msg_ model
            in
                ( mdl
                , Cmd.map DownloaderMsg cmd
                )
