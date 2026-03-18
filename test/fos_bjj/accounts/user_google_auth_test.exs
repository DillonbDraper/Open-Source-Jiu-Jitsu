defmodule FosBjj.Accounts.UserGoogleAuthTest do
  use FosBjj.DataCase, async: true

  import Ecto.Query
  import FosBjj.Fixtures

  alias FosBjj.Accounts.User
  alias FosBjj.Repo

  test "register_with_google creates a user and token" do
    email = "google#{unique_integer()}@example.com"
    sub = "google-sub-#{unique_integer()}"

    user =
      Ash.create!(
        User,
        %{
          user_info: %{"email" => email, "sub" => sub},
          oauth_tokens: %{"access_token" => "example"}
        },
        action: :register_with_google,
        authorize?: false
      )

    assert to_string(user.email) == email
    assert user.user_name == email
    assert match?(%DateTime{}, user.confirmed_at)
    assert is_binary(Ash.Resource.get_metadata(user, :token))
  end

  test "register_with_google upserts by unique email" do
    email = "google#{unique_integer()}@example.com"

    first_user =
      Ash.create!(
        User,
        %{
          user_info: %{"email" => email, "sub" => "first-#{unique_integer()}"},
          oauth_tokens: %{"access_token" => "first-token"}
        },
        action: :register_with_google,
        authorize?: false
      )

    second_user =
      Ash.create!(
        User,
        %{
          user_info: %{"email" => email, "sub" => "second-#{unique_integer()}"},
          oauth_tokens: %{"access_token" => "second-token"}
        },
        action: :register_with_google,
        authorize?: false
      )

    count = Repo.aggregate(from(u in "users", where: u.email == ^email), :count, :id)

    assert second_user.id == first_user.id
    assert second_user.user_name == first_user.user_name
    assert count == 1
  end

  test "register_with_google fails when derived username is already taken" do
    taken_user_name = "taken#{unique_integer()}@example.com"

    _existing =
      user_fixture(%{
        user_name: taken_user_name,
        email: "existing#{unique_integer()}@example.com"
      })

    assert {:error, error} =
             Ash.create(
               User,
               %{
                 user_info: %{
                   "email" => taken_user_name,
                   "sub" => "google-sub-#{unique_integer()}"
                 },
                 oauth_tokens: %{"access_token" => "example-token"}
               },
               action: :register_with_google,
               authorize?: false
             )

    assert Exception.message(error) =~
             "That username is already taken. Please choose another one."
  end
end
