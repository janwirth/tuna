import Benchmark.Runner exposing (BenchmarkProgram, program)

import Dict

main : BenchmarkProgram
main =
    program suite


import Array
import Benchmark exposing (..)

size = 1000
createfirstList _ = List.range size (size * 2)
createfirstDict _ = createfirstList _ |> List.map2 Tuple.pair |> Dict.fromList

createsecondDict : a -> Dict.Dict Int Int
createsecondDict _ = createfirstList _ |> List.map2 ((++) size |> Tuple.pair) |> Dict.fromList

insertList _ = createfirstList () ++ createfirstList ()
insertDict _ = createfirstDict () |> Dict.union (createsecondDict ())

suite : Benchmark
suite =
    let
        sampleArray =
            Array.initialize 100 identity
    in
    describe "Array"
        [ -- nest as many descriptions as you like
          describe "slice"
            [ benchmark "create dict" <|
                \_ -> create1000Dict
            , benchmark "create list" <|
                \_ -> create1000List
            , benchmark "insert into dict" <|
                \_ -> create1000Dict
            , benchmark "insert into list" <|
                \_ -> create1000List
            ]
        ]
