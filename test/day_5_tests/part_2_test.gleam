import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding
import gleam/int
import gleam/list
import gleam/result
import gleam/set
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub type Error {
  InvalidLine
  InvalidFreshIngredient
  FileStream(file_stream_error.FileStreamError)
}

type InventoryManagementSystem {
  InventoryManagementSystem(fresh_ingredient_ranges: set.Set(#(Int, Int)))
}

fn parse_inventory_management_system(
  stream: file_stream.FileStream,
) -> Result(InventoryManagementSystem, Error) {
  parse_inventory_management_system_loop(
    stream,
    InventoryManagementSystem(set.new()),
  )
}

fn parse_inventory_management_system_loop(
  stream: file_stream.FileStream,
  acc: InventoryManagementSystem,
) -> Result(InventoryManagementSystem, Error) {
  file_stream.read_line(stream)
  |> result.map_error(FileStream)
  |> result.map(string.trim)
  |> result.try(fn(line: String) {
    case line {
      "" -> Ok(acc)
      line -> {
        parse_fresh_ingredient_ranges(line)
        |> result.try(fn(fresh_ingredient_ranges: #(Int, Int)) {
          let new_fresh_ingredient_ranges =
            set.insert(acc.fresh_ingredient_ranges, fresh_ingredient_ranges)
          parse_inventory_management_system_loop(
            stream,
            InventoryManagementSystem(new_fresh_ingredient_ranges),
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

fn parse_fresh_ingredient_ranges(line: String) -> Result(#(Int, Int), Error) {
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

fn count_total_fresh_ingredient_ranges(
  inventory_management_system: InventoryManagementSystem,
) -> Int {
  let combined_fresh_ingredient_ranges =
    combine_overlapping_fresh_ingredient_ranges_loop(
      inventory_management_system.fresh_ingredient_ranges,
    )
  set.fold(
    combined_fresh_ingredient_ranges,
    0,
    fn(acc: Int, combined_fresh_ingredient_range: #(Int, Int)) {
      let #(start, end) = combined_fresh_ingredient_range
      acc + { end - start } + 1
    },
  )
}

type OverlappingFreshIngredientRanges {
  OverlappingFreshIngredientRanges(
    combined_range: #(Int, Int),
    overlapping_ranges: List(#(Int, Int)),
  )
}

fn combine_overlapping_fresh_ingredient_ranges_loop(
  fresh_ingredient_ranges: set.Set(#(Int, Int)),
) -> set.Set(#(Int, Int)) {
  let possible_overlapping_fresh_ingredient_ranges =
    list.find_map(
      set.to_list(fresh_ingredient_ranges),
      fn(fresh_ingredient_range: #(Int, Int)) {
        let #(start, end) = fresh_ingredient_range
        list.find_map(
          set.to_list(fresh_ingredient_ranges),
          fn(other_fresh_ingredient_range: #(Int, Int)) {
            let #(other_start, other_end) = other_fresh_ingredient_range
            let same_range = start == other_start && end == other_end
            let overlapping_range = start <= other_end && end >= other_start
            case same_range, overlapping_range {
              False, True ->
                Ok(
                  OverlappingFreshIngredientRanges(
                    #(int.min(start, other_start), int.max(end, other_end)),
                    [fresh_ingredient_range, other_fresh_ingredient_range],
                  ),
                )
              _, _ -> Error(Nil)
            }
          },
        )
      },
    )
  case possible_overlapping_fresh_ingredient_ranges {
    Ok(overlapping_fresh_ingredient_ranges) -> {
      let OverlappingFreshIngredientRanges(combined_range, overlapping_ranges) =
        overlapping_fresh_ingredient_ranges
      combine_overlapping_fresh_ingredient_ranges_loop(set.insert(
        set.drop(fresh_ingredient_ranges, overlapping_ranges),
        combined_range,
      ))
    }
    Error(_) -> fresh_ingredient_ranges
  }
}

pub fn part_2_example_test() {
  let assert Ok(fresh_available_ingredients_count) =
    file_stream.open_read_text(
      "test/day_5_tests/input-example.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_inventory_management_system)
    |> result.map(count_total_fresh_ingredient_ranges)
  assert fresh_available_ingredients_count == 14
}

pub fn part_2_test() {
  let assert Ok(fresh_available_ingredients_count) =
    file_stream.open_read_text(
      "test/day_5_tests/input.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_inventory_management_system)
    |> result.map(count_total_fresh_ingredient_ranges)
  assert fresh_available_ingredients_count == 344_260_049_617_193
}
