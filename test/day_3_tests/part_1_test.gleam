import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding
import gleam/dict
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
  InvalidDigit
  InvalidFirstJoltage
  InvalidSecondJoltage
  FileStream(file_stream_error.FileStreamError)
}

fn parse_lines(
  stream: file_stream.FileStream,
) -> Result(List(ParsedLine), Error) {
  parse_lines_loop(stream, [])
}

fn parse_lines_loop(
  stream: file_stream.FileStream,
  acc: List(ParsedLine),
) -> Result(List(ParsedLine), Error) {
  file_stream.read_line(stream)
  |> result.map_error(FileStream)
  |> result.map(string.trim)
  |> result.try(parse_line)
  |> result.try(fn(parsed_line: ParsedLine) {
    parse_lines_loop(stream, list.append(acc, [parsed_line]))
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

type ParsedLine {
  ParsedLine(battery_bank: dict.Dict(Int, List(JoltageIndex)))
}

type JoltageIndex {
  JoltageIndex(index: Int, is_last: Bool)
}

fn parse_line(line: String) -> Result(ParsedLine, Error) {
  parse_line_loop(line, ParsedLine(battery_bank: dict.new()), 0)
}

fn parse_line_loop(
  line: String,
  acc: ParsedLine,
  index: Int,
) -> Result(ParsedLine, Error) {
  case string.is_empty(line) {
    True -> Ok(acc)
    False -> {
      string.pop_grapheme(line)
      |> result.map_error(fn(_: Nil) { InvalidLine })
      |> result.try(fn(grapheme_and_rest: #(String, String)) {
        let #(grapheme, rest) = grapheme_and_rest
        case int.parse(grapheme) {
          Ok(digit) -> {
            let new_joltage_index = [
              JoltageIndex(index, string.is_empty(rest)),
            ]
            let new_joltage_indices = case dict.get(acc.battery_bank, digit) {
              Ok(joltage_indices) -> {
                list.append(joltage_indices, new_joltage_index)
              }
              Error(_) -> {
                new_joltage_index
              }
            }
            let new_acc =
              ParsedLine(dict.insert(
                acc.battery_bank,
                digit,
                new_joltage_indices,
              ))
            parse_line_loop(rest, new_acc, index + 1)
          }
          Error(_) -> Error(InvalidDigit)
        }
      })
    }
  }
}

fn largest_joltage(parsed_line: ParsedLine) -> Result(Int, Error) {
  let ParsedLine(battery_bank) = parsed_line
  list.range(9, 1)
  |> list.find_map(fn(joltage: Int) {
    case dict.get(battery_bank, joltage) {
      Ok(battery) -> {
        list.first(battery)
        |> result.try(fn(joltage_index: JoltageIndex) {
          case joltage_index.is_last {
            True -> Error(Nil)
            False -> Ok(#(joltage, joltage_index.index))
          }
        })
      }
      Error(_) -> Error(Nil)
    }
  })
  |> result.map_error(fn(_: Nil) { InvalidFirstJoltage })
  |> result.try(fn(first_joltage_and_joltage_index) {
    let #(first_joltage, first_joltage_index) = first_joltage_and_joltage_index
    list.range(9, 1)
    |> list.find_map(fn(joltage: Int) {
      case dict.get(battery_bank, joltage) {
        Ok(battery) -> {
          list.find_map(battery, fn(joltage_index: JoltageIndex) {
            case joltage_index.index > first_joltage_index {
              True -> Ok(joltage)
              False -> Error(Nil)
            }
          })
        }
        Error(_) -> Error(Nil)
      }
    })
    |> result.map_error(fn(_: Nil) { InvalidSecondJoltage })
    |> result.map(fn(second_joltage: Int) {
      first_joltage * 10 + second_joltage
    })
  })
}

fn sum_of_largest_joltages(stream: file_stream.FileStream) -> Result(Int, Error) {
  parse_lines(stream)
  |> result.try(fn(parsed_lines: List(ParsedLine)) {
    list.map(parsed_lines, largest_joltage)
    |> list.fold(
      Ok([]),
      fn(acc: Result(List(Int), Error), largest_joltage: Result(Int, Error)) {
        case acc, largest_joltage {
          Ok(acc), Ok(largest_joltage) ->
            Ok(list.append(acc, [largest_joltage]))
          Error(error), _ | _, Error(error) -> Error(error)
        }
      },
    )
  })
  |> result.map(fn(largest_joltages: List(Int)) {
    list.fold(largest_joltages, 0, fn(acc: Int, largest_joltage: Int) {
      acc + largest_joltage
    })
  })
}

pub fn part_1_example_test() {
  let assert Ok(sum_of_largest_joltages) =
    file_stream.open_read_text(
      "test/day_3_tests/input-example.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(sum_of_largest_joltages)
  assert sum_of_largest_joltages == 357
}

pub fn part_1_test() {
  let assert Ok(sum_of_largest_joltages) =
    file_stream.open_read_text(
      "test/day_3_tests/input.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(sum_of_largest_joltages)
  assert sum_of_largest_joltages == 17_207
}
