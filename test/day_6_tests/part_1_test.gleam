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
  InvalidOperator
  InvalidNumber
  InvalidColumnCount
  FileStream(file_stream_error.FileStreamError)
}

type Worksheet {
  Worksheet(numbers: List(List(Int)), operators: List(Operator))
}

type Operator {
  Add
  Multiply
}

fn parse_worksheet(stream: file_stream.FileStream) -> Result(Worksheet, Error) {
  parse_worksheet_loop(stream, Worksheet([], []))
}

fn parse_worksheet_loop(
  stream: file_stream.FileStream,
  acc: Worksheet,
) -> Result(Worksheet, Error) {
  file_stream.read_line(stream)
  |> result.map_error(FileStream)
  |> result.map(string.split(_, " "))
  |> result.map(list.map(_, string.trim))
  |> result.map(
    list.filter(_, fn(line_element: String) { !string.is_empty(line_element) }),
  )
  |> result.try(fn(line_elements: List(String)) {
    case list.first(line_elements) {
      Ok(line_element) if line_element == "*" || line_element == "+" -> {
        list.try_map(line_elements, fn(line_element: String) {
          case line_element {
            "*" -> Ok(Multiply)
            "+" -> Ok(Add)
            _ -> Error(InvalidOperator)
          }
        })
        |> result.map(fn(operators: List(Operator)) {
          Worksheet(acc.numbers, operators)
        })
      }
      Ok(_) -> {
        list.try_map(line_elements, int.parse)
        |> result.map_error(fn(_: Nil) { InvalidNumber })
        |> result.try(fn(numbers: List(Int)) {
          let new_numbers = list.append(acc.numbers, [numbers])
          parse_worksheet_loop(stream, Worksheet(new_numbers, acc.operators))
        })
      }
      Error(_) -> Error(InvalidLine)
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

fn calculate_worksheet_grand_total(worksheet: Worksheet) -> Result(Int, Error) {
  list.strict_zip(list.transpose(worksheet.numbers), worksheet.operators)
  |> result.map_error(fn(_: Nil) { InvalidColumnCount })
  |> result.try(fn(columns: List(#(List(Int), Operator))) {
    list.try_fold(
      columns,
      0,
      fn(grand_total: Int, column: #(List(Int), Operator)) {
        let #(numbers, operator) = column
        list.reduce(numbers, fn(acc: Int, number: Int) {
          case operator {
            Add -> acc + number
            Multiply -> acc * number
          }
        })
        |> result.map_error(fn(_: Nil) { InvalidColumnCount })
        |> result.map(fn(column_total: Int) { grand_total + column_total })
      },
    )
  })
}

pub fn part_1_example_test() {
  let assert Ok(worksheet_grand_total) =
    file_stream.open_read_text(
      "test/day_6_tests/input-example.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_worksheet)
    |> result.try(calculate_worksheet_grand_total)
  assert worksheet_grand_total == 4_277_556
}

pub fn part_1_test() {
  let assert Ok(worksheet_grand_total) =
    file_stream.open_read_text(
      "test/day_6_tests/input.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(parse_worksheet)
    |> result.try(calculate_worksheet_grand_total)
  assert worksheet_grand_total == 5_782_351_442_566
}
