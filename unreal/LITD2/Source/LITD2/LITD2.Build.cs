using UnrealBuildTool;

public class LITD2 : ModuleRules
{
    public LITD2(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

        PublicDependencyModuleNames.AddRange(new[]
        {
            "Core",
            "CoreUObject",
            "Engine",
            "InputCore",
            "Json",
            "UMG",
            "Slate",
            "SlateCore"
        });

        RuntimeDependencies.Add("$(ProjectDir)/Data/Remanence/sarei_seed.json");
        RuntimeDependencies.Add("$(ProjectDir)/Data/Remanence/sarei_ui_layout.json");
        RuntimeDependencies.Add("$(ProjectDir)/Data/Remanence/archive_audio_direction.json");
        RuntimeDependencies.Add("$(ProjectDir)/Data/Runs/sarei_faubourgs_run.json");
    }
}
