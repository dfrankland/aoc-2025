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
        let #(new_acc, _) =
          increment_roll_count(IfItDoesOrDoesNotExist, 0)(#(acc, 0), #(x, y))
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

fn calculate_adjacent_roll_counts(parsed_chars: ParsedChars) -> ParsedChars {
  let ParsedChars(adjacent_roll_counts) = parsed_chars
  let all_xy =
    dict.fold(
      adjacent_roll_counts,
      [],
      fn(
        acc: List(#(Int, Int)),
        x: Int,
        y_count: dict.Dict(Int, option.Option(Int)),
      ) {
        let new_acc =
          dict.fold(
            y_count,
            [],
            fn(acc: List(#(Int, Int)), y: Int, _count: option.Option(Int)) {
              list.append(acc, [#(x, y)])
            },
          )
        list.append(acc, new_acc)
      },
    )
  list.fold(all_xy, parsed_chars, increment_adjacent_roll_counts)
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
    count_rolls_with_less_than_n_adjacent_rolls_loop(n, parsed_chars)
  }
}

fn count_rolls_with_less_than_n_adjacent_rolls_loop(
  n: Int,
  parsed_chars: ParsedChars,
) -> Int {
  let ParsedChars(adjacent_roll_counts) =
    calculate_adjacent_roll_counts(parsed_chars)
  let #(
    adjacent_roll_counts_with_less_than_n_adjacent_rolls,
    rolls_with_less_than_n_adjacent_rolls_count,
  ) =
    dict.fold(
      adjacent_roll_counts,
      #(adjacent_roll_counts, 0),
      fn(
        acc: #(dict.Dict(Int, dict.Dict(Int, option.Option(Int))), Int),
        x: Int,
        y_count: dict.Dict(Int, option.Option(Int)),
      ) {
        let #(
          old_adjacent_roll_counts,
          old_rolls_with_less_than_n_adjacent_rolls_count,
        ) = acc
        let new_y_count_and_rolls_with_less_than_n_adjacent_rolls_count =
          dict.fold(
            y_count,
            #(y_count, old_rolls_with_less_than_n_adjacent_rolls_count),
            fn(
              acc: #(dict.Dict(Int, option.Option(Int)), Int),
              y: Int,
              count: option.Option(Int),
            ) {
              let #(
                old_y_count,
                old_rolls_with_less_than_n_adjacent_rolls_count,
              ) = acc
              case count {
                option.Some(count) if count < n -> {
                  let new_y_count = dict.drop(old_y_count, [y])
                  #(
                    new_y_count,
                    old_rolls_with_less_than_n_adjacent_rolls_count + 1,
                  )
                }
                option.Some(_count) -> {
                  let reset_y_count =
                    dict.insert(old_y_count, y, option.Some(0))
                  #(
                    reset_y_count,
                    old_rolls_with_less_than_n_adjacent_rolls_count,
                  )
                }
                _ -> acc
              }
            },
          )
        let #(new_y_count, new_rolls_with_less_than_n_adjacent_rolls_count) =
          new_y_count_and_rolls_with_less_than_n_adjacent_rolls_count
        let new_adjacent_roll_counts =
          dict.insert(old_adjacent_roll_counts, x, new_y_count)
        #(
          new_adjacent_roll_counts,
          new_rolls_with_less_than_n_adjacent_rolls_count,
        )
      },
    )

  case rolls_with_less_than_n_adjacent_rolls_count {
    0 -> rolls_with_less_than_n_adjacent_rolls_count
    _ ->
      count_rolls_with_less_than_n_adjacent_rolls_loop(
        n,
        ParsedChars(adjacent_roll_counts_with_less_than_n_adjacent_rolls),
      )
      + rolls_with_less_than_n_adjacent_rolls_count
  }
}

pub fn part_2_example_test() {
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
  assert rolls_with_less_than_n_adjacent_rolls_count == 43
}

pub fn part_2_test() {
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
  assert rolls_with_less_than_n_adjacent_rolls_count == 8310
}
