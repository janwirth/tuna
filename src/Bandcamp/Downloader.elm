port module Bandcamp.Downloader exposing (..)
{-| This module handles the bandcamp download process which is quite complicated to automate.
Given that a url to the download page is available the steps are:
1. fetch download page and extract the URL to request a an asset in the chosen format
2. request the asset url for chosen format
3. download the asset
4. unzip the asset, if necessary
5. read the unzipped directory
-}
import Dict
import Element
import Color
import Element.Background
import Element.Input
import Json.Decode as Decode
import Json.Encode as Encode
import RemoteData
import Bandcamp.Model
import FileSystem
import Element.Border


subscriptions : Bandcamp.Model.Downloads -> Sub Msg
subscriptions model =
    Sub.batch [
        bandcamp_downloader_in_formatter_url_retrieved
            (Bandcamp.Model.wrapPurchaseId >> FormatterUrlRetrieved)
      , bandcamp_downloader_in_asset_url_retrieved
            (Bandcamp.Model.wrapPurchaseId >> AssetUrlRetrieved)
      , bandcamp_downloader_in_download_progressed
            (Bandcamp.Model.wrapPurchaseId >> DownloadProgressed)
      , bandcamp_downloader_in_download_completed
            (Bandcamp.Model.PurchaseId >> DownloadCompleted)
      , bandcamp_downloader_in_files_extracted
            (Bandcamp.Model.PurchaseId >> FilesExtracted)
      , bandcamp_downloader_in_files_scanned
            (Bandcamp.Model.wrapPurchaseId >> FilesScanned)
    ]

type alias Token = {cookie : String, purchase_id: Int}

-- out ports
port bandcamp_downloader_out_formatter_url_requested : {cookie: String, purchase_id: Int, download_page_url: String} -> Cmd msg
port bandcamp_downloader_out_asset_url_requested : {cookie: String, purchase_id: Int, formatter_url: String} -> Cmd msg
port bandcamp_downloader_out_download_initiated : {purchase_id: Int, asset_url: String} -> Cmd msg
port bandcamp_downloader_out_unzip_initiated : Int -> Cmd msg
port bandcamp_downloader_out_scan_started : Int -> Cmd msg

-- in ports
port bandcamp_downloader_in_formatter_url_retrieved
    : ((Bandcamp.Model.PurchaseId_encoded, String) -> msg)
    -> Sub msg

port bandcamp_downloader_in_asset_url_retrieved
    : ((Bandcamp.Model.PurchaseId_encoded, String) -> msg)
    -> Sub msg

port bandcamp_downloader_in_download_progressed
    : ((Bandcamp.Model.PurchaseId_encoded, Bandcamp.Model.DownloadProgress) -> msg)
    -> Sub msg

port bandcamp_downloader_in_download_completed
    : (Bandcamp.Model.PurchaseId_encoded -> msg)
    -> Sub msg

port bandcamp_downloader_in_files_extracted
    : (Bandcamp.Model.PurchaseId_encoded -> msg)
    -> Sub msg

port bandcamp_downloader_in_files_scanned
    : ((Bandcamp.Model.PurchaseId_encoded, List FileSystem.FileRef) -> msg)
    -> Sub msg

type Msg =
    DownloadButtonClicked Bandcamp.Model.PurchaseId
  | ClearButtonClicked Bandcamp.Model.PurchaseId
  | FormatterUrlRetrieved (Bandcamp.Model.PurchaseId, String)
  | AssetUrlRetrieved (Bandcamp.Model.PurchaseId, String)
  | DownloadProgressed (Bandcamp.Model.PurchaseId, Bandcamp.Model.DownloadProgress)
  | DownloadCompleted Bandcamp.Model.PurchaseId
  | FilesExtracted Bandcamp.Model.PurchaseId
  | FilesScanned (Bandcamp.Model.PurchaseId, List FileSystem.FileRef)


update : Msg -> Bandcamp.Model.Model -> (Bandcamp.Model.Model, Cmd Msg)
update msg model =
    case model.cookie of
        Nothing -> (model, Cmd.none)
        Just (Bandcamp.Model.Cookie cookie) ->
            case msg of
                ClearButtonClicked (Bandcamp.Model.PurchaseId purchase_id) ->
                        ({ model
                        | downloads = Dict.remove purchase_id model.downloads
                        }, Cmd.none)
                DownloadButtonClicked id ->
                    let
                        (Bandcamp.Model.PurchaseId purchase_id) = id
                        return =
                            model.library
                            |> RemoteData.toMaybe
                            |> Maybe.andThen (\{download_urls} -> Dict.get (to_download_id id) download_urls)
                            |> Maybe.map startdownload
                            |> Maybe.withDefault (model, Cmd.none)
                        startdownload download_page_url =
                            let
                                downloadCmd =
                                    bandcamp_downloader_out_formatter_url_requested
                                        { cookie = cookie
                                        , purchase_id = purchase_id
                                        , download_page_url = download_page_url
                                        }
                                mdl =
                                    { model
                                    | downloads = Dict.insert purchase_id Bandcamp.Model.initDownload model.downloads
                                    }
                            in
                                (mdl, downloadCmd)
                    in
                        return
                FormatterUrlRetrieved (Bandcamp.Model.PurchaseId purchase_id, formatter_url) ->
                    let
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads = Dict.insert purchase_id Bandcamp.Model.RequestingAssetUrl model.downloads
                        mdl =
                            { model | downloads = newDownloads}
                        cmd =
                            bandcamp_downloader_out_asset_url_requested
                                { cookie = cookie
                                , purchase_id = purchase_id
                                , formatter_url = formatter_url
                                }
                    in
                        (mdl
                        , cmd
                        )
                AssetUrlRetrieved (Bandcamp.Model.PurchaseId purchase_id, asset_url) ->
                    let
                        -- we will update the download once
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads =
                            Dict.insert purchase_id Bandcamp.Model.waitingDownload model.downloads
                        mdl =
                            { model | downloads = newDownloads}
                        cmd =
                            bandcamp_downloader_out_download_initiated
                                { purchase_id = purchase_id
                                , asset_url = asset_url
                                }
                    in
                        (mdl , cmd)
                DownloadProgressed (Bandcamp.Model.PurchaseId purchase_id, pct) ->
                    let
                        dl = Bandcamp.Model.Downloading (Bandcamp.Model.InProgress pct)
                        -- we will update the download once
                        newDownloads : Bandcamp.Model.Downloads
                        newDownloads =
                            Dict.insert purchase_id dl model.downloads
                        mdl =
                            { model | downloads = newDownloads}
                    in
                        (mdl , Cmd.none)
                DownloadCompleted (Bandcamp.Model.PurchaseId purchase_id) ->
                    ({ model | downloads = Dict.insert purchase_id Bandcamp.Model.Unzipping model.downloads}
                    , bandcamp_downloader_out_unzip_initiated
                                purchase_id
                    )

                FilesExtracted (Bandcamp.Model.PurchaseId purchase_id) ->
                    ({ model | downloads = Dict.insert purchase_id Bandcamp.Model.Unzipping model.downloads}
                    , bandcamp_downloader_out_scan_started purchase_id
                    )
                FilesScanned (Bandcamp.Model.PurchaseId purchase_id, files) ->
                    ({ model
                    | downloads = Dict.insert purchase_id (Bandcamp.Model.Completed files) model.downloads
                    }
                    , Cmd.none
                    )




{-| The keys for the redownload_urls in bandcamp have a particular format -}
to_download_id : Bandcamp.Model.PurchaseId -> String
to_download_id (Bandcamp.Model.PurchaseId id) =
    "p" ++ String.fromInt id

viewDownloadButton : Bandcamp.Model.Downloads -> Bandcamp.Model.PurchaseId -> Element.Element Msg
viewDownloadButton model item_id =
    let
        viewButton =
            Element.Input.button
                [Element.padding 10, Element.Border.rounded 5, Element.Background.color Color.playerGrey]
                { label = Element.text "Download"
                , onPress = Just <| DownloadButtonClicked item_id
                }
        clearButton =
            Element.Input.button
                [Element.padding 10, Element.Border.rounded 5, Element.Background.color Color.playerGrey]
                { label = Element.text "Clear"
                , onPress = Just <| ClearButtonClicked item_id
                }
    in
        case Bandcamp.Model.get_download item_id model of
            Nothing -> viewButton
            Just progress -> Element.column [Element.spacing 5] [clearButton, viewProgress progress]

viewProgress : Bandcamp.Model.Download -> Element.Element msg
viewProgress p =
    case p of
            Bandcamp.Model.RequestingFormatUrl -> Element.text "1/5 - Probing"
            Bandcamp.Model.RequestingAssetUrl -> Element.text "2/5 - Formatting"
            Bandcamp.Model.Downloading Bandcamp.Model.Waiting -> Element.text <| "3/5 - Downloading..."
            Bandcamp.Model.Downloading (Bandcamp.Model.InProgress pct) -> Element.text <| "3/5 - Downloading " ++ (String.fromInt pct)
            Bandcamp.Model.Unzipping -> Element.text "4/5 - Extracting"
            Bandcamp.Model.Scanning -> Element.text "5/5 - Scanning"
            Bandcamp.Model.Completed files ->
                Element.text <| "Downloaded " ++ String.fromInt (List.length files) ++ " files"
            Bandcamp.Model.Error -> Element.text "Problem"

