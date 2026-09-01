using UnrealBuildTool;
using System.Collections.Generic;

public class LITD2Target : TargetRules
{
    public LITD2Target(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("LITD2");
    }
}
