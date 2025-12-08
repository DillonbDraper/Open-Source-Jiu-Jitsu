defmodule FosBjj.Accounts do
  use Ash.Domain, otp_app: :fos_bjj, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource FosBjj.Accounts.Token
    resource FosBjj.Accounts.User
  end
end
