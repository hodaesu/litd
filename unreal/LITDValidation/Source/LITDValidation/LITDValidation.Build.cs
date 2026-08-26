using UnrealBuildTool;

public class LITDValidation : ModuleRules
{
    public LITDValidation(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[] {
            "Core", "CoreUObject", "Engine", "InputCore", "Slate", "SlateCore"
        });
    }
}
