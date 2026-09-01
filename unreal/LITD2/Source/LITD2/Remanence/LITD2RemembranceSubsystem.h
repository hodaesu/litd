#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "LITD2RemembranceDataAssets.h"
#include "LITD2RemembranceSubsystem.generated.h"

class ULITD2RemembranceSaveGame;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FLITD2RemembranceEntryChanged, FName, EntryId, ELITD2RemembranceDiscoveryState, NewState);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITD2RemembranceReconstructed, FName, ReconstructionId);

UCLASS()
class LITD2_API ULITD2RemembranceSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    UPROPERTY(BlueprintAssignable, Category="LITD2|Remanence")
    FLITD2RemembranceEntryChanged OnEntryChanged;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Remanence")
    FLITD2RemembranceReconstructed OnReconstructionCompleted;

    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence")
    void SetEntryState(FName EntryId, ELITD2RemembranceDiscoveryState NewState);

    UFUNCTION(BlueprintPure, Category="LITD2|Remanence")
    ELITD2RemembranceDiscoveryState GetEntryState(FName EntryId) const;

    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence")
    void DiscoverSource(FName SourceId);

    UFUNCTION(BlueprintPure, Category="LITD2|Remanence")
    bool HasDiscoveredSource(FName SourceId) const;

    UFUNCTION(BlueprintPure, Category="LITD2|Remanence")
    bool CanReconstruct(const ULITD2RemembranceReconstruction* Reconstruction) const;

    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence")
    bool ApplyReconstruction(const ULITD2RemembranceReconstruction* Reconstruction);

    UFUNCTION(BlueprintPure, Category="LITD2|Remanence")
    bool IsReconstructionCompleted(FName ReconstructionId) const;

    UFUNCTION(BlueprintPure, Category="LITD2|Remanence")
    bool IsUnlocked(FName UnlockId) const;

    UFUNCTION(BlueprintPure, Category="LITD2|Remanence")
    int32 GetIntegerUnlockValue(FName UnlockId, int32 DefaultValue = 0) const;

    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence|Save")
    bool SaveArchives();

    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence|Save")
    bool LoadArchives();

private:
    UPROPERTY()
    TObjectPtr<ULITD2RemembranceSaveGame> RuntimeState;

    static const FString SaveSlotName;

    ULITD2RemembranceSaveGame* EnsureState();
    const ULITD2RemembranceSaveGame* GetState() const;
    bool IsKnownEntry(FName EntryId) const;
    bool IsRequirementGroupSatisfied(const FLITD2KnowledgeRequirementGroup& Group) const;
    void ApplyUnlock(const FLITD2GameplayUnlock& Unlock);
};
