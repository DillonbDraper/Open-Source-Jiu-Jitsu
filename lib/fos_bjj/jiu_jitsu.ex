defmodule FosBjj.JiuJitsu do
  use Ash.Domain, otp_app: :fos_bjj, extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  defdelegate create_in_action_video(params, selected_grips, selected_techniques, current_user),
    to: FosBjj.JiuJitsu.InActionVideos

  resources do
    resource(FosBjj.JiuJitsu.Position)
    resource(FosBjj.JiuJitsu.SubPosition)
    resource(FosBjj.JiuJitsu.Orientation)
    resource(FosBjj.JiuJitsu.Grip)
    resource(FosBjj.JiuJitsu.Action)
    resource(FosBjj.JiuJitsu.Technique)
    resource(FosBjj.JiuJitsu.PositionOrientation)
    resource(FosBjj.JiuJitsu.ActionSubPositionOrientation)
    resource(FosBjj.JiuJitsu.VideoType)
    resource(FosBjj.JiuJitsu.Video)
    resource(FosBjj.JiuJitsu.InActionStaging)
    resource(FosBjj.JiuJitsu.VideoGrip)
    resource(FosBjj.JiuJitsu.TechniqueSubPosition)
    resource(FosBjj.JiuJitsu.VideoTechnique)
    resource(FosBjj.JiuJitsu.VideoNote)
  end
end
