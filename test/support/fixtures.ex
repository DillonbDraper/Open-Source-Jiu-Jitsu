defmodule FosBjj.Fixtures do
  import Ecto.Query

  alias FosBjj.Repo
  alias FosBjj.Accounts.User
  alias FosBjj.Accounts.UserMessage
  alias FosBjj.JiuJitsu.ActionSubPositionOrientation
  alias FosBjj.JiuJitsu.Technique
  alias FosBjj.JiuJitsu.Video
  alias FosBjj.JiuJitsu.VideoTechnique

  def unique_integer do
    System.unique_integer([:positive])
  end

  # Basic fixture system until we implement factories (if ever)
  def user_fixture(attrs \\ %{}) do
    password = Map.get(attrs, :password, "password1234")
    email = Map.get(attrs, :email, "user#{unique_integer()}@example.com")
    user_name = Map.get(attrs, :user_name, "user#{unique_integer()}")

    params = %{
      user_name: user_name,
      email: email,
      password: password,
      password_confirmation: password
    }

    user = Ash.create!(User, params, action: :register_with_password, authorize?: false)

    user =
      case Map.get(attrs, :role) do
        nil -> user
        role -> Ash.update!(user, %{role: role}, action: :update_role, authorize?: false)
      end

    confirmed_at = Map.get(attrs, :confirmed_at)
    confirmed? = Map.get(attrs, :confirmed, false)

    case {confirmed?, confirmed_at} do
      {true, nil} ->
        _ =
          Repo.update_all(from(u in "users", where: u.id == ^user.id),
            set: [confirmed_at: DateTime.utc_now()]
          )

        Ash.get!(User, user.id, authorize?: false)

      {_, %DateTime{} = timestamp} ->
        _ =
          Repo.update_all(from(u in "users", where: u.id == ^user.id),
            set: [confirmed_at: timestamp]
          )

        Ash.get!(User, user.id, authorize?: false)

      _ ->
        user
    end
  end

  def user_with_token_fixture(attrs \\ %{}) do
    password = Map.get(attrs, :password, "password1234")
    email = Map.get(attrs, :email, "user#{unique_integer()}@example.com")
    user_name = Map.get(attrs, :user_name, "user#{unique_integer()}")

    params = %{
      user_name: user_name,
      email: email,
      password: password,
      password_confirmation: password
    }

    user = Ash.create!(User, params, action: :register_with_password, authorize?: false)
    token = Ash.Resource.get_metadata(user, :token)

    user =
      case Map.get(attrs, :role) do
        nil -> user
        role -> Ash.update!(user, %{role: role}, action: :update_role, authorize?: false)
      end

    confirmed_at = Map.get(attrs, :confirmed_at)
    confirmed? = Map.get(attrs, :confirmed, false)

    updated_user =
      case {confirmed?, confirmed_at} do
        {true, nil} ->
          timestamp = DateTime.utc_now()

          _ =
            Repo.update_all(from(u in "users", where: u.id == ^user.id),
              set: [confirmed_at: timestamp]
            )

          %{user | confirmed_at: timestamp}

        {_, %DateTime{} = timestamp} ->
          _ =
            Repo.update_all(from(u in "users", where: u.id == ^user.id),
              set: [confirmed_at: timestamp]
            )

          %{user | confirmed_at: timestamp}

        _ ->
          user
      end

    {updated_user, token}
  end

  def video_fixture(attrs \\ %{}) do
    user = Map.get(attrs, :user, user_fixture())
    video_id = Map.get(attrs, :video_id, "vid#{unique_integer()}")
    title = Map.get(attrs, :title, "Video #{unique_integer()}")
    attire = Map.get(attrs, :attire, :gi)
    description = Map.get(attrs, :description, "Test video description")
    thumbnail_url = Map.get(attrs, :thumbnail_url, "https://example.com/thumb.jpg")

    params = %{
      video_id: video_id,
      title: title,
      description: description,
      attire: attire,
      thumbnail_url: thumbnail_url
    }

    Ash.create!(Video, params, action: :create, actor: user)
  end

  def position_tree_fixture do
    unique = unique_integer()
    user = user_fixture(%{confirmed: true})

    position_name = "position_#{unique}"
    orientation_name = "orientation_#{unique}"
    sub_position_name = "sub_position_#{unique}"
    action_with_technique = "action_with_#{unique}"
    action_without_technique = "action_without_#{unique}"

    Repo.insert_all("positions", [
      %{name: position_name, label: "Position #{unique}"}
    ])

    Repo.insert_all("orientations", [
      %{name: orientation_name, label: "Orientation #{unique}"}
    ])

    Repo.insert_all("sub_positions", [
      %{name: sub_position_name, label: "Sub Position #{unique}", position_name: position_name}
    ])

    Repo.insert_all("actions", [
      %{name: action_with_technique, label: "Action With #{unique}"},
      %{name: action_without_technique, label: "Action Without #{unique}"}
    ])

    Repo.insert_all("position_orientations", [
      %{position_name: position_name, orientation_name: orientation_name}
    ])

    Ash.create!(ActionSubPositionOrientation, %{
      action_name: action_with_technique,
      sub_position_name: sub_position_name,
      orientation_name: orientation_name
    })

    Ash.create!(ActionSubPositionOrientation, %{
      action_name: action_without_technique,
      sub_position_name: sub_position_name,
      orientation_name: orientation_name
    })

    technique =
      Ash.create!(
        Technique,
        %{
          name: "Technique #{unique}",
          orientation_name: orientation_name,
          sub_position_name: sub_position_name,
          action_name: action_with_technique
        },
        action: :create,
        actor: user
      )

    video = video_fixture(%{user: user, title: "Video #{unique}"})

    Ash.create!(VideoTechnique, %{video_id: video.id, technique_id: technique.id})

    %{
      user: user,
      position_name: position_name,
      orientation_name: orientation_name,
      sub_position_name: sub_position_name,
      action_with_technique: action_with_technique,
      action_without_technique: action_without_technique,
      technique: technique,
      video: video
    }
  end

  def message_fixture(attrs \\ %{}) do
    type = Map.get(attrs, :type, :video_shared_by_coach)
    recipient = Map.get(attrs, :recipient, user_fixture())

    case type do
      :video_shared_by_coach ->
        sender = Map.get(attrs, :sender, user_fixture(%{role: "coach"}))
        video = Map.get(attrs, :video, video_fixture(%{user: sender}))
        body = Map.get(attrs, :body, "Check this out")

        Ash.create!(
          UserMessage,
          %{
            body: body,
            recipient_id: recipient.id,
            shared_video_id: video.id
          },
          action: :send,
          actor: sender
        )

      :system_notification ->
        body = Map.get(attrs, :body, "System notification")

        Ash.create!(
          UserMessage,
          %{
            body: body,
            recipient_id: recipient.id
          },
          action: :send_system_message
        )
    end
  end
end
