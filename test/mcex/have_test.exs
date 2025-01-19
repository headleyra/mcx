defmodule Mcex.HaveTest do
  use ExUnit.Case, async: true
  alias Mcex.Have

  describe "stats/2" do
    test "calculates the average interval between 'have' days", do: true
    test "expects today's date as the 2nd argument", do: true

    the_map = """
    returns a map with the following keys:
    one: first date
    tot: total number of days
    hav: number of 'have' days
    avg: average interval between 'have' days
    int: the last 2 intervals
    """

    test the_map, do: true

    test "errors with an 'empty' dates string" do
      assert Have.stats("", d(5)) == {:error, :nodates}
      assert Have.stats("\n \t ", d(8)) == {:error, :nodates}
    end

    test "works with 1 date" do
      assert Have.stats(ds(2), d(3)) == %{one: d(2), tot: 2, hav: 1, avg: 1, int: [1]}
      assert Have.stats(ds(11), d(15)) == %{one: d(11), tot: 5, hav: 1, avg: 4, int: [4]}
    end

    test "works with 1 date (where <today> == <the have date>)" do
      assert Have.stats(ds(2), d(2)) == %{one: d(2), tot: 1, hav: 1, avg: 0.0, int: [0]}
    end

    test "works with 2 or more dates (white space separated)" do
      assert Have.stats("#{ds(1)} #{ds(2)}", d(5)) == %{one: d(1), tot: 5, hav: 2, avg: 1.5, int: [0, 3]}
    end

    test "works with 2 or more dates (where <today> == <last have date>)" do
      assert Have.stats(ds([1, 2]), d(2)) == %{one: d(1), tot: 2, hav: 2, avg: 0, int: [0, 0]}
      assert Have.stats(ds([2, 5, 11]), d(11)) == %{one: d(2), tot: 10, hav: 3, avg: 2.33, int: [5, 0]}
    end

    test "works with 2 or more dates (regardless of chronological order)" do
      assert Have.stats(ds([2, 1]), d(5)) == %{one: d(1), tot: 5, hav: 2, avg: 1.5, int: [0, 3]}
      assert Have.stats(ds([2, 1, 5]), d(7)) == %{one: d(1), tot: 7, hav: 3, avg: 1.33, int: [2, 2]}
      assert Have.stats(ds([9, 7, 1]), d(12)) == %{one: d(1), tot: 12, hav: 3, avg: 3.0, int: [1, 3]}
    end

    test "treats duplicate dates as one date" do
      s1 = Have.stats(ds([11, 11]), d(15))
      s2 = Have.stats(ds([11, 11, 11]), d(15))

      assert s1 == %{one: d(11), tot: 5, hav: 1, avg: 4, int: [4]}
      assert s1 == s2
    end

    test "errors with bad dates" do
      assert Have.stats("2014-01-05 2011-5-123", d(15)) == {:error, :parse}
      assert Have.stats("1987.3.7", d(5)) == {:error, :parse}
      assert Have.stats("foo-bar-biz", d(7)) == {:error, :parse}
    end
  end

  defp d(d) do
    Date.new!(2017, 1, d) 
  end

  defp ds(day) when is_integer(day) do
    "2017-1-#{day}"
  end

  defp ds(days) when is_list(days) do
    Enum.map_join(days, "\n", fn day -> "2017-1-#{day}" end)
  end
end
