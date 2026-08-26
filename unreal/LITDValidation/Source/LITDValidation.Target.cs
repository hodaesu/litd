using UnrealBuildTool;

public class LITDValidationTarget : TargetRules
{
    public LITDValidationTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
        ExtraModuleNames.Add("LITDValidation");
    }
}
