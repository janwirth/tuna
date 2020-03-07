port module FileSystem exposing (..)
import Json.Decode as Decode

port directories_scanned : (Decode.Value -> a) -> Sub a
port scan_directories : List String -> Cmd msg
