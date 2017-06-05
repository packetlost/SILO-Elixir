defmodule CubDB.Store.File.Blocks do
  @block_size 1024
  @data_marker 0
  @header_marker 42

  def add_markers(bin, loc, block_size \\ @block_size) do
    at_block_boundary(bin, loc, block_size, &add/3)
  end

  def strip_markers(bin, loc, block_size \\ @block_size) do
    at_block_boundary(bin, loc, block_size, &strip/3)
  end

  def length_with_headers(loc, length, block_size \\ @block_size) do
    case rem(loc, block_size) do
      0 -> trunc(headers_length(length, block_size) + length)
      r ->
        prefix = block_size - r
        rest = length - prefix
        trunc(prefix + headers_length(rest, block_size) + rest)
    end
  end

  def add_header_marker(bin, loc, block_size \\ @block_size) do
    case rem(loc, block_size) do
      0 ->
        {loc, <<@header_marker>> <> add_markers(bin, loc + 1, block_size)}
      r ->
        block_rest = block_size - r
        padding = String.pad_leading(<<>>, block_rest, <<@data_marker>>)
        header_bytes = add_markers(bin, loc + block_rest + 1, block_size)
        {loc + block_rest, padding <> <<@header_marker>> <> header_bytes}
    end
  end

  def latest_possible_header(loc, block_size \\ @block_size) do
    div(loc - 1, block_size) * block_size
  end

  def header_marker?(marker), do: @header_marker == marker

  defp at_block_boundary(bin, loc, block_size, function) do
    case rem(loc, block_size) do
      0 -> function.(bin, <<>>, block_size)
      r ->
        block_rest = block_size - r
        if byte_size(bin) <= block_rest do
          bin
        else
          <<prefix::binary-size(block_rest), rest::binary>> = bin
          function.(rest, prefix, block_size)
        end
    end
  end

  defp add(bin, acc, block_size) do
    data_size = block_size - 1
    if byte_size(bin) <= data_size do
      acc <> <<@data_marker>> <> bin
    else
      <<block::binary-size(data_size), rest::binary>> = bin
      add(rest, acc <> <<@data_marker>> <> block, block_size)
    end
  end

  defp strip(bin, acc, block_size) do
    if byte_size(bin) <= block_size do
      <<_::binary-1, block::binary>> = bin
      acc <> block
    else
      data_size = block_size - 1
      <<_::binary-1, block::binary-size(data_size), rest::binary>> = bin
      strip(rest, acc <> block, block_size)
    end
  end

  defp headers_length(length, block_size) do
    Float.ceil(length / (block_size - 1))
  end
end