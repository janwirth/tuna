module Bandcamp.Id exposing
    ( parsePurchaseId
    , emptyDict_
    , getBy
    , removeBy
    , Dict_
    , Id
    , decodeDict_
    , encodeDict_
    , decodeId
    , encodeId
    , fromPort
    , toPort
    , ForPort
    , insertBy
    , wrapDict_
    , dictToList
    )
import Dict
import Json.Encode as Encode
import Json.Decode as Decode


dictToList : Dict_ a -> List (Id, a)
dictToList (Dict_ dict) =
    Dict.toList dict
    |> List.map (Tuple.mapFirst Id)

wrapDict_ = Dict_
type alias ForPort = Int
fromPort id = Id id
toPort (Id id) = id

parsePurchaseId : String -> Maybe Id
parsePurchaseId p =
    case String.uncons p of
        Just ('p', p_id) -> String.toInt p_id |> Maybe.map Id
        _ -> Nothing

{-| format

1234567890 : Int
-}
-- [decgen-start]
type Id = Id Int
type Dict_ a = Dict_ (Dict.Dict Int a)
emptyDict_ = Dict_ Dict.empty

-- [decgen-generated-start] -- DO NOT MODIFY or remove this line
decodeDictInt_ParamA_ decodeA =
   let
      decodeDictInt_ParamA_Tuple =
         Decode.map2
            (\a1 a2 -> (a1, a2))
               ( Decode.field "A1" Decode.int )
               ( Decode.field "A2" decodeA )
   in
      Decode.map Dict.fromList (Decode.list decodeDictInt_ParamA_Tuple)

decodeDict_ decodeA =
   Decode.map Dict_ (decodeDictInt_ParamA_ decodeA)


decodeId =
   Decode.map Id Decode.int

encodeDictInt_ParamA_ encodeA a =
   let
      encodeDictInt_ParamA_Tuple (a1,a2) =
         Encode.object
            [ ("A1", Encode.int a1)
            , ("A2", encodeA a2) ]
   in
      (Encode.list encodeDictInt_ParamA_Tuple) (Dict.toList a)

encodeDict_ encodeA (Dict_ a1) =
   encodeDictInt_ParamA_ encodeA a1

encodeId (Id a1) =
   Encode.int a1 
-- [decgen-end]

{-| The purchase id is the item_id found in the item_id field prepended with a "p"
Example: p123456809
We just need the part after 'p'.
-}
parse_download_id : String -> Maybe Id
parse_download_id =
    String.uncons
    >> Maybe.andThen (Tuple.second >> String.toInt)
    >> Maybe.map Id

getBy : Id -> Dict_ a -> Maybe a
getBy (Id id) (Dict_ dict) =
    Dict.get id dict

removeBy : Id -> Dict_ a -> Dict_ a
removeBy (Id id) (Dict_ dict) =
    Dict.remove id dict
    |> Dict_


insertBy : Id -> a -> Dict_ a -> Dict_ a
insertBy (Id id) item (Dict_ dict) =
    Dict.insert id item dict
    |> Dict_

