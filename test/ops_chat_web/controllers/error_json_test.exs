defmodule OpsChatWeb.ErrorJSONTest do
  use OpsChatWeb.ConnCase, async: true

  test "renders 404" do
    assert OpsChatWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert OpsChatWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
