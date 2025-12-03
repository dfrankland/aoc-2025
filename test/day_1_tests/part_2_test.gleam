import file_streams/file_stream
import file_streams/file_stream_error
import file_streams/text_encoding
import gleam/int
import gleam/result
import gleam/string
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

const dial_position_start = 50

const dial_position_max = 100

type State {
  State(
    stream: file_stream.FileStream,
    dial_position: Int,
    dial_position_zero_count: Int,
  )
}

type Direction {
  Right
  Left
}

fn update_dial_position(
  state: State,
  direction: Direction,
  distance: Int,
) -> State {
  let distance_without_extra_rotations = distance % dial_position_max
  let rotation_total = case direction {
    Right -> state.dial_position + distance_without_extra_rotations
    Left -> state.dial_position - distance_without_extra_rotations
  }
  let new_dial_position =
    { dial_position_max + rotation_total } % dial_position_max
  let additional_zero_counts =
    { distance / dial_position_max }
    + case
      state.dial_position != 0
      && { rotation_total <= 0 || rotation_total >= dial_position_max }
    {
      True -> 1
      False -> 0
    }
  State(
    stream: state.stream,
    dial_position: new_dial_position,
    dial_position_zero_count: state.dial_position_zero_count
      + additional_zero_counts,
  )
}

pub type Error {
  InvalidLine
  InvalidDistance
  InvalidDirection
  FileStream(file_stream_error.FileStreamError)
}

fn process_lines(state: State) -> Result(State, Error) {
  file_stream.read_line(state.stream)
  |> result.map_error(fn(error: file_stream_error.FileStreamError) {
    FileStream(error)
  })
  |> result.map(string.trim_end)
  |> result.try(fn(trimmed_line: String) {
    string.pop_grapheme(trimmed_line)
    |> result.map_error(fn(_: Nil) { InvalidLine })
  })
  |> result.try(fn(line_parts: #(String, String)) {
    let #(direction_string, distance_string) = line_parts
    case int.parse(distance_string) {
      Ok(distance) -> Ok(#(direction_string, distance))
      Error(_) -> Error(InvalidDistance)
    }
  })
  |> result.try(fn(direction_string_and_distance: #(String, Int)) {
    let #(direction_string, distance) = direction_string_and_distance
    case direction_string {
      "R" -> process_lines(update_dial_position(state, Right, distance))
      "L" -> process_lines(update_dial_position(state, Left, distance))
      _ -> Error(InvalidDirection)
    }
  })
  |> result.try_recover(fn(error: Error) {
    case error {
      FileStream(fs_error) ->
        case fs_error {
          file_stream_error.Eof -> Ok(state)
          _ -> Error(error)
        }
      _ -> Error(error)
    }
  })
}

pub fn part_2_example_test() {
  let assert Ok(state) =
    file_stream.open_read_text(
      "test/day_1_tests/input-example.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(fn(stream: file_stream.FileStream) {
      process_lines(State(
        stream: stream,
        dial_position: dial_position_start,
        dial_position_zero_count: 0,
      ))
    })
  assert state.dial_position_zero_count == 6
}

pub fn part_2_test() {
  let assert Ok(state) =
    file_stream.open_read_text(
      "test/day_1_tests/input.txt",
      text_encoding.Unicode,
    )
    |> result.map_error(fn(error: file_stream_error.FileStreamError) {
      FileStream(error)
    })
    |> result.try(fn(stream: file_stream.FileStream) {
      process_lines(State(
        stream: stream,
        dial_position: dial_position_start,
        dial_position_zero_count: 0,
      ))
    })
  assert state.dial_position_zero_count == 6027
}
