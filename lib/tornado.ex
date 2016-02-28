defmodule Tornado do
  import Month

  ### Public Functions ###

  def main(args) do
    args
    |> parse_args
    |> get_tornado_data
    |> process
  end

  def get_tornado_data([url: url]) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> body
      {:ok, %HTTPoison.Response{status_code: 400}} ->
        IO.puts "404 - Not Found!"
      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts "Error: #{reason}"
    end
  end

  def process(body) do
    String.split(body, "")
    |> truncate_body
    |> split_rows
    |> parse_rows
    |> IO.puts
  end

  def truncate_body(body) do
    Enum.slice(
      body,
      get_truncate_offset(body, "JAN"),
      length(body)
    )
  end

  @doc """
  Takes full body text and cuts out everything leading up to first line,
  identified by the provided pattern. Here, we identify the first line of data
  via the "JAN" month identifier.

  Ex. http://www.spc.noaa.gov/climo/online/monthly/newm.html

  @param [String] body
  """
  def get_truncate_offset(body, pattern) do
    _get_truncate_offset(
      body,
      0,
      pattern,
      String.split(pattern, "") |> Enum.at(0),
      ""
    )
  end

  @doc """
  Takes a truncated body (i.e. assumed to start with month-based rows) & splits
  at newlines - takes first 12 rows for the 12 months of data

  @param [String] body - the truncated body
  """
  def split_rows(body) do
    body
    |> Enum.join("")
    |> String.split("\n")
    |> Enum.take(12)
  end

  @doc """
  Takes array of row strings and parses into Map + Structs dataset

  @param [Array] rows - Collection of row strings
  """
  def parse_rows(rows) do
    _parse_rows(
      rows,
      %{
        2016 => generate_empty_dataset,
        2015 => generate_empty_dataset,
        2014 => generate_empty_dataset,
        2013 => generate_empty_dataset
      },
      0
    )
  end

  @doc """
  Takes a single string row, splits into an array of characters, and loops thru
  the chars to parse stats based on custom triggers

  @param [String] row - Single row string
  @param [Integer] month - Number corresponding to month of year
  @param [Map] data - Map of parsed data to be eventually returned
  """
  def parse_single_row(row, month, data) do
    _parse_single_row(String.split(row, ""), data, "", false, 0, month)
  end

  ### Private Functions ###

  defp _get_truncate_offset([], _, _, _, _), do: "No offset found!"
  defp _get_truncate_offset(_body, offset, pattern, _trigger, match) when pattern == match do
    offset - 3
  end
  defp _get_truncate_offset([ head | tail ], offset, pattern, trigger, _match) when head == trigger do
    _get_truncate_offset(tail, offset + 1, pattern, trigger, trigger)
  end
  defp _get_truncate_offset([ head | tail ], offset, pattern, trigger, match) do
    case String.length(match) do
      3 -> _get_truncate_offset(tail, offset + 1, pattern, trigger, "")
      _ -> _get_truncate_offset(tail, offset + 1, pattern, trigger, match <> head)
    end
  end

  defp _parse_rows(_, data, 12), do: data
  defp _parse_rows(rows, data, count) do
    _parse_rows(
      rows,
      parse_single_row(Enum.at(rows, count), count + 1, data),
      count + 1
    )
  end

  defp _parse_single_row([], data, _, _, _, _), do: data
  defp _parse_single_row([ head | tail ], data, num, coll, count, month) do
    case Integer.parse(head) do
      { _int, _ } -> _parse_single_row(tail, data, num <> head, true, count, month)
      :error -> cond do
        coll ->
          updated = add_new_num(data, num, count, month)
          _parse_single_row(tail, updated, "", false, count + 1, month)
        head == "-" && (count == 0 || count == 5 || count == 10) ->
          updated = add_new_num(data, "0", count, month)
          _parse_single_row(tail, updated, "", false, count + 1, month)
        true ->
          _parse_single_row(tail, data, num, coll, count, month)
      end
    end
  end

  defp add_new_num(data, num, count, month) do
    cond do
      count in 0..4 ->
        case count do
          0 -> put_in(data[2016][get_month(month)].count, String.to_integer(num))
          1 -> put_in(data[2015][get_month(month)].count, String.to_integer(num))
          2 -> put_in(data[2014][get_month(month)].count, String.to_integer(num))
          3 -> put_in(data[2013][get_month(month)].count, String.to_integer(num))
          4 -> data
        end
      count in 5..9 ->
        case count do
          5 -> put_in(data[2016][get_month(month)].deaths, String.to_integer(num))
          6 -> put_in(data[2015][get_month(month)].deaths, String.to_integer(num))
          7 -> put_in(data[2014][get_month(month)].deaths, String.to_integer(num))
          8 -> put_in(data[2013][get_month(month)].deaths, String.to_integer(num))
          9 -> data
        end
      count in 10..14 ->
        case count do
          10 -> put_in(data[2016][get_month(month)].killers, String.to_integer(num))
          11 -> put_in(data[2015][get_month(month)].killers, String.to_integer(num))
          12 -> put_in(data[2014][get_month(month)].killers, String.to_integer(num))
          13 -> put_in(data[2013][get_month(month)].killers, String.to_integer(num))
          14 -> data
        end
    end
  end

  ### Helpers + Parsers ###

  defp parse_args(args) do
    { options, _, _ } = OptionParser.parse(args, switches: [url: :string])
    options
  end

  defp get_month(num) do
    case num do
      1 -> :jan
      2 -> :feb
      3 -> :mar
      4 -> :apr
      5 -> :may
      6 -> :jun
      7 -> :jul
      8 -> :aug
      9 -> :sep
      10 -> :oct
      11 -> :nov
      12 -> :dec
    end
  end

  defp generate_empty_dataset do
    %{
      jan: %Month{},
      feb: %Month{},
      mar: %Month{},
      apr: %Month{},
      may: %Month{},
      jun: %Month{},
      jul: %Month{},
      aug: %Month{},
      sep: %Month{},
      oct: %Month{},
      nov: %Month{},
      dec: %Month{}
    }
  end
end
