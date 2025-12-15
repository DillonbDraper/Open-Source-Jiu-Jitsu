defmodule FosBjj.JiuJitsu do
  use Ash.Domain, otp_app: :fos_bjj, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource FosBjj.JiuJitsu.Position
    resource FosBjj.JiuJitsu.SubPosition
    resource FosBjj.JiuJitsu.Orientation
    resource FosBjj.JiuJitsu.Grip
    resource FosBjj.JiuJitsu.Technique
    resource FosBjj.JiuJitsu.TechniquePosition
    resource FosBjj.JiuJitsu.PositionOrientation
    resource FosBjj.JiuJitsu.Video
    resource FosBjj.JiuJitsu.VideoGrip
  end
end
