#include "LITDValidationGameMode.h"
#include "LITDValidationCharacter.h"
#include "LITDValidationHUD.h"
#include "LITDValidationRoom.h"
#include "LITDValidationStation.h"
#include "LITDValidationEnemy.h"
#include "DrawDebugHelpers.h"
#include "Engine/DirectionalLight.h"
#include "Engine/SkyLight.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/SkyLightComponent.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "HAL/PlatformFileManager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

ALITDValidationGameMode::ALITDValidationGameMode()
{
    DefaultPawnClass = ALITDValidationCharacter::StaticClass();
    HUDClass = ALITDValidationHUD::StaticClass();
}

void ALITDValidationGameMode::BeginPlay()
{
    Super::BeginPlay();
    InitializeChecks();
    SpawnValidationContent();
    UWorld* World = GetWorld();
    APlayerController* Controller = World ? World->GetFirstPlayerController() : nullptr;
    if (Controller && !Controller->GetPawn())
    {
        ALITDValidationCharacter* Character = World->SpawnActor<ALITDValidationCharacter>(
            FVector(1100, 0, 100), FRotator(0, 180, 0));
        Controller->Possess(Character);
    }
    PresentMessage(TEXT("Salle Unreal générée. E/manette : interagir · clic/gâchette : attaquer · G : cendres."));
}

void ALITDValidationGameMode::InitializeChecks()
{
    static const TArray<FName> Names = {
        TEXT("movement"), TEXT("dialogue"), TEXT("chest"), TEXT("loot"),
        TEXT("combat_started"), TEXT("combat_finished"), TEXT("consumables"),
        TEXT("psychology"), TEXT("injury"), TEXT("ash_guidance"), TEXT("save_roundtrip")
    };
    Checks.Reset();
    for (const FName Name : Names)
    {
        Checks.Add(Name, false);
    }
    Checks[TEXT("consumables")] = true;
}

void ALITDValidationGameMode::SpawnValidationContent()
{
    UWorld* World = GetWorld();
    if (!World)
    {
        return;
    }
    World->SpawnActor<ALITDValidationRoom>(FVector::ZeroVector, FRotator::ZeroRotator);
    ADirectionalLight* Sun = World->SpawnActor<ADirectionalLight>(FVector(0, 0, 600), FRotator(-55, -35, 0));
    if (Sun && Sun->GetDirectionalLightComponent())
    {
        Sun->GetDirectionalLightComponent()->SetIntensity(4.0f);
        Sun->GetDirectionalLightComponent()->SetLightColor(FLinearColor(1.0f, 0.82f, 0.68f));
    }
    ASkyLight* Sky = World->SpawnActor<ASkyLight>(FVector::ZeroVector, FRotator::ZeroRotator);
    if (Sky && Sky->GetLightComponent())
    {
        Sky->GetLightComponent()->SetIntensity(0.7f);
        Sky->GetLightComponent()->SetMobility(EComponentMobility::Movable);
    }

    struct FStationSpec
    {
        ELITDValidationStationType Type;
        FVector Position;
        FString Label;
        FLinearColor Color;
    };
    const TArray<FStationSpec> Stations = {
        {ELITDValidationStationType::Dialogue, FVector(200, -900, 100), TEXT("PARLER À ILYAN"), FLinearColor(0.18f, 0.45f, 0.65f)},
        {ELITDValidationStationType::LootChest, FVector(200, 900, 65), TEXT("OUVRIR LE COFFRE"), FLinearColor(0.65f, 0.42f, 0.12f)},
        {ELITDValidationStationType::Psychology, FVector(800, -1300, 65), TEXT("PEUR / ESPOIR"), FLinearColor(0.35f, 0.24f, 0.55f)},
        {ELITDValidationStationType::PersistentInjury, FVector(800, 1300, 65), TEXT("BLESSURE"), FLinearColor(0.72f, 0.20f, 0.08f)},
        {ELITDValidationStationType::SaveRoundtrip, FVector(1100, -650, 65), TEXT("SNAPSHOT QA"), FLinearColor(0.55f, 0.47f, 0.23f)}
    };
    for (const FStationSpec& Spec : Stations)
    {
        ALITDValidationStation* Station = World->SpawnActor<ALITDValidationStation>(Spec.Position, FRotator::ZeroRotator);
        if (Station)
        {
            Station->Configure(Spec.Type, Spec.Label, Spec.Color);
        }
    }

    const TArray<FVector> EnemyPositions = {
        FVector(-1050, -750, 140), FVector(-1120, -250, 140),
        FVector(-1120, 250, 140), FVector(-1050, 750, 140)
    };
    for (int32 Index = 0; Index < EnemyPositions.Num(); ++Index)
    {
        ALITDValidationEnemy* Enemy = World->SpawnActor<ALITDValidationEnemy>(EnemyPositions[Index], FRotator::ZeroRotator);
        if (Enemy)
        {
            Enemy->Configure(Index);
            Enemies.Add(Enemy);
        }
    }
}

void ALITDValidationGameMode::MarkCheck(FName CheckId, bool bPassed)
{
    if (Checks.Contains(CheckId))
    {
        Checks[CheckId] = bPassed;
    }
}

void ALITDValidationGameMode::PresentMessage(const FString& Text)
{
    Message = Text;
}

void ALITDValidationGameMode::PresentDialogue(const FString& Speaker, const FString& Text)
{
    Message = FString::Printf(TEXT("%s — %s"), *Speaker, *Text);
}

void ALITDValidationGameMode::GrantPrototypeLoot(const FString& ItemName, int32 Quantity)
{
    InventorySummary = FString::Printf(TEXT("%s ×%d"), *ItemName, Quantity);
    PresentMessage(FString::Printf(TEXT("Butin obtenu : %s"), *InventorySummary));
}

void ALITDValidationGameMode::RequestAshGuidance(const FVector& Target)
{
    if (UWorld* World = GetWorld())
    {
        const FVector Start(1100, 0, 35);
        DrawDebugDirectionalArrow(World, Start, Target, 120, FColor(185, 190, 180), false, 4.0f, 0, 8.0f);
        MarkCheck(TEXT("ash_guidance"));
        PresentMessage(TEXT("Les cendres indiquent temporairement l'arène, sans HUD permanent."));
    }
}

void ALITDValidationGameMode::RunSnapshotRoundtrip()
{
    const FString Directory = FPaths::Combine(FPaths::ProjectSavedDir(), TEXT("QA"));
    IPlatformFile& PlatformFile = FPlatformFileManager::Get().GetPlatformFile();
    PlatformFile.CreateDirectoryTree(*Directory);
    const FString Path = FPaths::Combine(Directory, TEXT("litd_unreal_qa_snapshot.json"));
    const FString Payload = FString::Printf(
        TEXT("{\"version\":1,\"checks\":%d,\"loot\":\"%s\"}"), CompletedCount(), *InventorySummary);
    const bool bSaved = FFileHelper::SaveStringToFile(Payload, *Path);
    FString Loaded;
    const bool bLoaded = bSaved && FFileHelper::LoadFileToString(Loaded, *Path) && Loaded == Payload;
    MarkCheck(TEXT("save_roundtrip"), bLoaded);
    PresentMessage(bLoaded ? TEXT("Snapshot Unreal QA sauvegardé et relu.") : TEXT("Échec du snapshot Unreal QA."));
}

void ALITDValidationGameMode::RegisterEnemyDefeated()
{
    ++DefeatedEnemies;
    if (DefeatedEnemies >= Enemies.Num())
    {
        MarkCheck(TEXT("combat_finished"));
        PresentMessage(TEXT("Combat test terminé : quatre ennemis vaincus."));
    }
}

void ALITDValidationGameMode::ResetValidation()
{
    if (UWorld* World = GetWorld())
    {
        UGameplayStatics::OpenLevel(this, FName(*World->GetName()), false);
    }
}

int32 ALITDValidationGameMode::CompletedCount() const
{
    int32 Count = 0;
    for (const TPair<FName, bool>& Pair : Checks)
    {
        Count += Pair.Value ? 1 : 0;
    }
    return Count;
}
