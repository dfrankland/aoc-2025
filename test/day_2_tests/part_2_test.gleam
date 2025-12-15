import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub type Error {
  InvalidNumber
  InvalidRange
  FileStream(file_stream_error.FileStreamError)
}

type ParseNumberState {
  ParseNumberState(stream: file_stream.FileStream, chars: String)
}

fn parse_number(
  parse_number_state: ParseNumberState,
) -> Result(option.Option(#(Int, option.Option(String))), Error) {
  case file_stream.read_chars(parse_number_state.stream, 1) {
    Ok(char) ->
      case char {
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ->
          parse_number(ParseNumberState(
            parse_number_state.stream,
            parse_number_state.chars <> char,
          ))
        "\n" -> parse_number(parse_number_state)
        c -> {
          int.parse(parse_number_state.chars)
          |> result.map_error(fn(_: Nil) { InvalidNumber })
          |> result.map(fn(number: Int) {
            option.Some(#(number, option.Some(c)))
          })
        }
      }
    Error(error) ->
      case error {
        file_stream_error.Eof -> {
          case parse_number_state.chars {
            "" -> Ok(option.None)
            chars ->
              int.parse(chars)
              |> result.map_error(fn(_: Nil) { InvalidNumber })
              |> result.map(fn(number: Int) {
                option.Some(#(number, option.None))
              })
          }
        }
        _ -> Error(FileStream(error))
      }
  }
}

fn parse_range(
  stream: file_stream.FileStream,
) -> Result(option.Option(#(Int, Int)), Error) {
  parse_number(ParseNumberState(stream, ""))
  |> result.try(
    fn(range_start_and_left_over: option.Option(#(Int, option.Option(String)))) {
      case range_start_and_left_over {
        option.Some(range_start_and_left_over) -> {
          let #(range_start, left_over) = range_start_and_left_over
          case left_over {
            option.Some("-") -> Ok(option.Some(range_start))
            _ -> Error(InvalidRange)
          }
        }
        option.None -> Ok(option.None)
      }
    },
  )
  |> result.try(fn(range_start: option.Option(Int)) {
    case range_start {
      option.Some(range_start) -> {
        parse_number(ParseNumberState(stream, ""))
        |> result.try(
          fn(
            range_end_and_left_over: option.Option(
              #(Int, option.Option(String)),
            ),
          ) {
            case range_end_and_left_over {
              option.Some(range_end_and_left_over) -> {
                let #(range_end, left_over) = range_end_and_left_over
                case left_over {
                  option.Some(",") | option.Some("\n") | option.None ->
                    Ok(option.Some(#(range_start, range_end)))
                  _ -> Error(InvalidRange)
                }
              }
              option.None -> Error(InvalidRange)
            }
          },
        )
      }
      option.None -> Ok(option.None)
    }
  })
}

fn parse_ranges(
  stream: file_stream.FileStream,
  ranges: List(#(Int, Int)),
) -> Result(List(#(Int, Int)), Error) {
  parse_range(stream)
  |> result.try(fn(range: option.Option(#(Int, Int))) {
    case range {
      option.Some(range) -> parse_ranges(stream, list.append(ranges, [range]))
      option.None -> Ok(ranges)
    }
  })
}

type Digits {
  Digits(values: List(Int), length: Int, value: Int)
}

fn digits(number: Int, acc: Digits) -> Digits {
  let new_acc =
    Digits(list.append([number % 10], acc.values), acc.length + 1, acc.value)
  let new_number = number / 10
  case new_number {
    0 -> new_acc
    _ -> digits(new_number, new_acc)
  }
}

fn undigits(numbers: List(Int)) -> Int {
  undigits_loop(numbers, 0)
}

fn undigits_loop(numbers: List(Int), acc: Int) -> Int {
  case numbers {
    [] -> acc
    [digit, ..rest] -> undigits_loop(rest, acc * 10 + digit)
  }
}

fn int_power(base: Int, exponent: Int) -> Int {
  list.range(1, exponent)
  |> list.fold(1, fn(acc: Int, _: Int) { acc * base })
}

fn multiply_number_part(number_part: Int, divided_length: Int) -> Int {
  let d = digits(number_part, Digits([], 0, number_part))
  undigits(
    list.range(1, divided_length)
    |> list.flat_map(fn(_) { d.values }),
  )
}

fn next_invalid_numbers(number: Int) -> List(Int) {
  let d = digits(number, Digits([], 0, number))
  invalid_number_moduli(number)
  |> list.map(fn(modulus: Int) {
    let number_has_divisible_place_values = d.length % modulus == 0
    case number_has_divisible_place_values {
      True -> {
        let divided_length = d.length / modulus
        let number_part = undigits(list.take(d.values, modulus))
        let multiplied_number_digits =
          multiply_number_part(number_part, divided_length)
        case multiplied_number_digits > number {
          True -> multiplied_number_digits
          False -> {
            let next_number_part = number_part + 1
            let next_number_part_has_more_place_values =
              next_number_part >= int_power(10, modulus)
            case next_number_part_has_more_place_values {
              True -> int_power(10, d.length)
              False -> multiply_number_part(next_number_part, divided_length)
            }
          }
        }
      }
      False -> int_power(10, d.length)
    }
  })
}

fn invalid_number_moduli(number: Int) -> List(Int) {
  let d = digits(number, Digits([], 0, number))
  list.range(1, d.length - 1)
  |> list.filter_map(fn(modulus: Int) {
    case d.length % modulus == 0 {
      True -> Ok(modulus)
      False -> Error(Nil)
    }
  })
}

fn is_invalid_number(number: Int) -> Bool {
  let d = digits(number, Digits([], 0, number))
  number >= 10
  && invalid_number_moduli(number)
  |> list.any(fn(modulus: Int) {
    let repeated_digits =
      list.range(1, d.length / modulus)
      |> list.flat_map(fn(_) { list.take(d.values, modulus) })
    d.values == repeated_digits
  })
}

fn number_is_in_range(number: Int, range: #(Int, Int)) -> Bool {
  number >= range.0 && number <= range.1
}

fn invalid_numbers_in_range_loop(
  range: #(Int, Int),
  acc: set.Set(Int),
) -> set.Set(Int) {
  case
    number_is_in_range(range.0, range) && set.contains(acc, range.0) == False
  {
    True -> {
      let new_acc = case is_invalid_number(range.0) {
        True -> set.insert(acc, range.0)
        False -> acc
      }
      next_invalid_numbers(range.0)
      |> list.fold(new_acc, fn(inner_acc: set.Set(Int), range_start: Int) {
        let new_range = #(range_start, range.1)
        invalid_numbers_in_range_loop(new_range, inner_acc)
      })
    }
    False -> acc
  }
}

fn invalid_numbers_in_range(range: #(Int, Int)) -> set.Set(Int) {
  invalid_numbers_in_range_loop(range, set.new())
}

pub fn part_2_example_test() {
  let assert Ok(invalid_numbers_sum) =
    file_stream.open_read_text(
      "test/day_2_tests/input-example.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(fn(stream: file_stream.FileStream) {
      parse_ranges(stream, [])
    })
    |> result.map(fn(ranges: List(#(Int, Int))) {
      list.map(ranges, fn(range: #(Int, Int)) {
        invalid_numbers_in_range(range)
      })
      |> list.fold(
        set.new(),
        fn(acc: set.Set(Int), invalid_numbers: set.Set(Int)) {
          set.union(acc, invalid_numbers)
        },
      )
      |> set.to_list()
      |> list.fold(0, fn(acc: Int, number: Int) { acc + number })
    })
  assert invalid_numbers_sum == 4_174_379_265
}

pub fn part_2_test() {
  let assert Ok(invalid_numbers_sum) =
    file_stream.open_read_text(
      "test/day_2_tests/input.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(fn(stream: file_stream.FileStream) {
      parse_ranges(stream, [])
    })
    |> result.map(fn(ranges: List(#(Int, Int))) {
      list.map(ranges, fn(range: #(Int, Int)) {
        invalid_numbers_in_range(range)
      })
      |> list.fold(
        set.new(),
        fn(acc: set.Set(Int), invalid_numbers: set.Set(Int)) {
          set.union(acc, invalid_numbers)
        },
      )
      |> set.to_list()
      |> list.fold(0, fn(acc: Int, number: Int) { acc + number })
    })
  assert invalid_numbers_sum == 43_287_141_963
}
