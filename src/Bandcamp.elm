module Bandcamp exposing (..)

import RemoteData.Http exposing (defaultConfig)
import Http
import Element
import Html.Events
import Json.Decode as Decode
import Json.Encode as Encode
import Html
import RemoteData

-- [decgen-start]
type Cookie = Cookie String

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeCookie =
   Decode.map Cookie Decode.string

encodeCookie (Cookie a1) =
   Encode.string a1 
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

cookieToHeader : Cookie -> Http.Header
cookieToHeader (Cookie c) =
    Http.header "Cookie" c

getInitData : Cookie -> Cmd (RemoteData.WebData Decode.Value)
getInitData (Cookie cookie) =
    let
        encoded = Encode.string cookie
    in
        RemoteData.Http.post
            "http://localhost:8080/bandcamp/init"
            identity
            Decode.value
            encoded

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
