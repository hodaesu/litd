#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "LITDValidationGameMode.generated.h"

class ALITDValidationEnemy;

UCLASS()
class LITDVALIDATION_API ALITDValidationGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    ALITDValidationGameMode();
    virtual void BeginPlay() override;

    void MarkCheck(FName CheckId, bool bPassed = true);
    void PresentMessage(const FString& Text);
    void PresentDialogue(const FString& Speaker, const FString& Text);
    void GrantPrototypeLoot(const FString& ItemName, int32 Quantity);
    void RequestAshGuidance(const FVector& Target);
    void RunSnapshotRoundtrip();
    void RegisterEnemyDefeated();
    void ResetValidation();

    const TMap<FName, bool>& GetChecks() const { return Checks; }
    const FString& GetMessage() const { return Message; }
    const FString& GetInventorySummary() const { return InventorySummary; }
    int32 CompletedCount() const;

private:
    TMap<FName, bool> Checks;
    FString Message;
    FString InventorySummary;
    int32 DefeatedEnemies = 0;
    TArray<TWeakObjectPtr<ALITDValidationEnemy>> Enemies;

    void InitializeChecks();
    void SpawnValidationContent();
};
