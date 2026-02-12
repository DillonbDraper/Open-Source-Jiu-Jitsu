defmodule FosBjj.Accounts do
  use Ash.Domain, otp_app: :fos_bjj, extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(FosBjj.Accounts.Academy)
    resource(FosBjj.Accounts.AcademyUser)
    resource(FosBjj.Accounts.ContributorApplication)
    resource(FosBjj.Accounts.Token)
    resource(FosBjj.Accounts.User)
    resource(FosBjj.Accounts.Role)
    resource(FosBjj.Accounts.UserMessage)
    resource(FosBjj.Accounts.StudentCoachRelationship)
  end
end
