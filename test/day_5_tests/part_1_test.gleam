import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub type Error {
  InvalidLine
  InvalidFreshIngredient
  InvalidAvailableIngredient
  FileStream(file_stream_error.FileStreamError)
}

type InventoryManagementSystem {
  InventoryManagementSystem(
    fresh_ingredients: List(#(Int, Int)),
    available_ingredients: List(Int),
  )
}

fn parse_inventory_management_system(
  stream: file_stream.FileStream,
) -> Result(InventoryManagementSystem, Error) {
  parse_inventory_management_system_loop(
    stream,
    InventoryManagementSystem([], []),
    ParsingFreshIngredients,
  )
}

type ParseState {
  ParsingFreshIngredients
  ParsingAvailableIngredients
}

fn parse_inventory_management_system_loop(
  stream: file_stream.FileStream,
  acc: InventoryManagementSystem,
  parse_state: ParseState,
) -> Result(InventoryManagementSystem, Error) {
  file_stream.read_line(stream)
  |> result.map_error(FileStream)
  |> result.map(string.trim)
  |> result.try(fn(line: String) {
    case parse_state, line {
      ParsingFreshIngredients, "" ->
        parse_inventory_management_system_loop(
          stream,
          acc,
          ParsingAvailableIngredients,
        )
      ParsingFreshIngredients, line -> {
        parse_fresh_ingredients(line)
        |> result.try(fn(fresh_ingredients: #(Int, Int)) {
          let new_fresh_ingredients =
            list.append(acc.fresh_ingredients, [fresh_ingredients])
          parse_inventory_management_system_loop(
            stream,
            InventoryManagementSystem(
              new_fresh_ingredients,
              acc.available_ingredients,
            ),
            ParsingFreshIngredients,
          )
        })
      }
      ParsingAvailableIngredients, "" -> Ok(acc)
      ParsingAvailableIngredients, line -> {
        int.parse(line)
        |> result.map_error(fn(_: Nil) { InvalidAvailableIngredient })
        |> result.try(fn(available_ingredient: Int) {
          let new_available_ingredients =
            list.append(acc.available_ingredients, [available_ingredient])
          parse_inventory_management_system_loop(
            stream,
            InventoryManagementSystem(
              acc.fresh_ingredients,
              new_available_ingredients,
            ),
            ParsingAvailableIngredients,
          )
        })
      }
    }
  })
  |> result.try_recover(fn(error: Error) {
    case error {
      FileStream(fs_error) ->
        case fs_error {
          file_stream_error.Eof -> Ok(acc)
          _ -> Error(error)
        }
      _ -> Error(error)
    }
  })
}

fn parse_fresh_ingredients(line: String) -> Result(#(Int, Int), Error) {
  string.split_once(line, "-")
  |> result.map_error(fn(_: Nil) { InvalidFreshIngredient })
  |> result.try(fn(range: #(String, String)) {
    let #(range_start, range_end) = range
    case int.parse(range_start), int.parse(range_end) {
      Ok(range_start), Ok(range_end) -> Ok(#(range_start, range_end))
      _, _ -> Error(InvalidFreshIngredient)
    }
  })
}

fn count_fresh_available_ingredients(
  inventory_management_system: InventoryManagementSystem,
) -> Int {
  let InventoryManagementSystem(fresh_ingredients, available_ingredients) =
    inventory_management_system
  list.fold(available_ingredients, 0, fn(acc: Int, available_ingredient: Int) {
    case
      list.find(fresh_ingredients, fn(fresh_ingredient: #(Int, Int)) {
        fresh_ingredient.0 <= available_ingredient
        && fresh_ingredient.1 >= available_ingredient
      })
    {
      Ok(_) -> acc + 1
      Error(_) -> acc
    }
  })
}

pub fn part_1_example_test() {
  let assert Ok(fresh_available_ingredients_count) =
    file_stream.open_read_text(
      "test/day_5_tests/input-example.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_inventory_management_system)
    |> result.map(count_fresh_available_ingredients)
  assert fresh_available_ingredients_count == 3
}

pub fn part_1_test() {
  let assert Ok(fresh_available_ingredients_count) =
    file_stream.open_read_text(
      "test/day_5_tests/input.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_inventory_management_system)
    |> result.map(count_fresh_available_ingredients)
  assert fresh_available_ingredients_count == 529
}
