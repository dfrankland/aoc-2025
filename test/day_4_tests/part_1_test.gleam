import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding
import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub type Error {
  InvalidChar
  FileStream(file_stream_error.FileStreamError)
}

type ParsedChars {
  ParsedChars(
    adjacent_roll_counts: dict.Dict(Int, dict.Dict(Int, option.Option(Int))),
  )
}

fn parse_chars(stream: file_stream.FileStream) -> Result(ParsedChars, Error) {
  parse_chars_loop(stream, ParsedChars(dict.new()), 0, 0)
}

fn parse_chars_loop(
  stream: file_stream.FileStream,
  acc: ParsedChars,
  x: Int,
  y: Int,
) -> Result(ParsedChars, Error) {
  file_stream.read_chars(stream, 1)
  |> result.map_error(FileStream)
  |> result.try(fn(char: String) {
    case char {
      "\n" -> parse_chars_loop(stream, acc, 0, y + 1)
      "." -> parse_chars_loop(stream, acc, x + 1, y)
      "@" -> {
        let new_acc = increment_adjacent_roll_counts(acc, #(x, y))
        parse_chars_loop(stream, new_acc, x + 1, y)
      }
      _ -> Error(InvalidChar)
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

fn increment_adjacent_roll_counts(
  parsed_chars: ParsedChars,
  xy: #(Int, Int),
) -> ParsedChars {
  let #(x, y) = xy
  let adjacent_roll_xy =
    list.filter(
      [
        // left
        #(x - 1, y),
        // top left
        #(x - 1, y - 1),
        // top
        #(x, y - 1),
        // top right
        #(x + 1, y - 1),
      ],
      fn(xy: #(Int, Int)) {
        let #(x, y) = xy
        x >= 0 && y >= 0
      },
    )
  let #(new_parsed_chars, new_adjacent_roll_count) =
    list.fold(
      adjacent_roll_xy,
      #(parsed_chars, 0),
      increment_roll_count(IfItExists, 1),
    )
  let #(new_parsed_chars, _) =
    increment_roll_count(IfItDoesOrDoesNotExist, new_adjacent_roll_count)(
      #(new_parsed_chars, 0),
      xy,
    )
  new_parsed_chars
}

type IncrementRollCountCondition {
  IfItExists
  IfItDoesOrDoesNotExist
}

fn increment_roll_count(
  condition: IncrementRollCountCondition,
  increment_by: Int,
) -> fn(#(ParsedChars, Int), #(Int, Int)) -> #(ParsedChars, Int) {
  fn(
    parsed_chars_and_new_adjacent_roll_count: #(ParsedChars, Int),
    xy: #(Int, Int),
  ) -> #(ParsedChars, Int) {
    let #(ParsedChars(adjacent_roll_counts), new_adjacent_roll_count) =
      parsed_chars_and_new_adjacent_roll_count
    let #(x, y) = xy
    let y_count = case dict.get(adjacent_roll_counts, x) {
      Ok(y_count) -> y_count
      Error(_) -> dict.new()
    }
    let count = case dict.get(y_count, y) {
      Ok(count) -> count
      Error(_) -> option.None
    }
    case condition, count {
      IfItExists, option.None -> #(
        ParsedChars(adjacent_roll_counts),
        new_adjacent_roll_count,
      )
      _, _ -> #(
        ParsedChars(dict.insert(
          adjacent_roll_counts,
          x,
          dict.insert(y_count, y, case count {
            option.Some(count) -> option.Some(count + increment_by)
            option.None -> option.Some(increment_by)
          }),
        )),
        new_adjacent_roll_count + 1,
      )
    }
  }
}

fn count_rolls_with_less_than_n_adjacent_rolls(n: Int) -> fn(ParsedChars) -> Int {
  fn(parsed_chars: ParsedChars) -> Int {
    let ParsedChars(adjacent_roll_counts) = parsed_chars
    dict.fold(
      adjacent_roll_counts,
      0,
      fn(acc: Int, _x: Int, y_count: dict.Dict(Int, option.Option(Int))) {
        acc
        + dict.fold(
          y_count,
          0,
          fn(acc: Int, _y: Int, count: option.Option(Int)) {
            case count {
              option.Some(count) if count < n -> {
                acc + 1
              }
              _ -> acc
            }
          },
        )
      },
    )
  }
}

pub fn part_1_example_test() {
  let assert Ok(rolls_with_less_than_n_adjacent_rolls_count) =
    file_stream.open_read_text(
      "test/day_4_tests/input-example.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_chars)
    |> result.map(count_rolls_with_less_than_n_adjacent_rolls(4))
  assert rolls_with_less_than_n_adjacent_rolls_count == 13
}

pub fn part_1_test() {
  let assert Ok(rolls_with_less_than_n_adjacent_rolls_count) =
    file_stream.open_read_text(
      "test/day_4_tests/input.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_chars)
    |> result.map(count_rolls_with_less_than_n_adjacent_rolls(4))
  assert rolls_with_less_than_n_adjacent_rolls_count == 1457
}
