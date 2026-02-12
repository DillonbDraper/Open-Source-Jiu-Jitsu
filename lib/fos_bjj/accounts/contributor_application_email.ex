defmodule FosBjj.Accounts.ContributorApplicationEmail do
  @moduledoc """
  Delivers contributor application emails to the configured recipient.
  """

  import Swoosh.Email

  alias FosBjj.Mailer

  @spec deliver_application(FosBjj.Accounts.User.t(), String.t(), list()) ::
          {:ok, term()} | {:error, term()}
  def deliver_application(user, body, attachments) do
    recipient = Application.get_env(:fos_bjj, :contributor_application_email)

    if is_nil(recipient) do
      {:error, :missing_recipient}
    else
      email =
        new()
        |> from({"Open Source BJJ", "noreply@ossbjj.org"})
        |> to(recipient)
        |> reply_to(to_string(user.email))
        |> subject("OSSBJJ Contributor Application")
        |> text_body(build_body(user, body))
        |> add_attachments(attachments)

      Mailer.deliver(email)
    end
  end

  defp build_body(user, body) do
    """
    Applicant: #{user.user_name} (#{user.email})
    User ID: #{user.id}

    Message:
    #{body}
    """
  end

  defp add_attachments(email, attachments) do
    Enum.reduce(attachments, email, fn file_attachment, acc ->
      attachment(acc, file_attachment)
    end)
  end
end
