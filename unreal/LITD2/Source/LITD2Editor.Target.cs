using UnrealBuildTool;
using System.Collections.Generic;

public class LITD2EditorTarget : TargetRules
{
    public LITD2EditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("LITD2");
    }
}
