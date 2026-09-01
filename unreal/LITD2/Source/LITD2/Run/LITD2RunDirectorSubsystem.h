#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "LITD2RunDirectorSubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FLITD2RunZoneEvent, FName, ZoneId, FText, ZoneTitle);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITD2RunBranchEvent, FName, BranchId);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITD2RunRemanenceEvent, FName, EntryId);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITD2RunBossPhaseEvent, int32, PhaseIndex);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FLITD2RunSimpleEvent);

USTRUCT(BlueprintType)
struct FLITD2RunZoneDefinition
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly)
    FName ZoneId = NAME_None;

    UPROPERTY(BlueprintReadOnly)
    FText Title;

    UPROPERTY(BlueprintReadOnly)
    FString Type;

    UPROPERTY(BlueprintReadOnly)
    FName BossId = NAME_None;

    UPROPERTY(BlueprintReadOnly)
    FName MandatoryRemanenceId = NAME_None;
};

USTRUCT(BlueprintType)
struct FLITD2RunRuntimeState
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly)
    FName RunId = NAME_None;

    UPROPERTY(BlueprintReadOnly)
    int32 CurrentZoneIndex = INDEX_NONE;

    UPROPERTY(BlueprintReadOnly)
    FName SelectedBranchId = NAME_None;

    UPROPERTY(BlueprintReadOnly)
    FName SelectedOathId = NAME_None;

    UPROPERTY(BlueprintReadOnly)
    int32 PotionCapacity = 3;

    UPROPERTY(BlueprintReadOnly)
    int32 PotionCount = 3;

    UPROPERTY(BlueprintReadOnly)
    int32 MaxHealth = 1000;

    UPROPERTY(BlueprintReadOnly)
    int32 CurrentHealth = 1000;

    UPROPERTY(BlueprintReadOnly)
    int32 LockedHealth = 0;

    UPROPERTY(BlueprintReadOnly)
    int32 TraumaLevel = 0;

    UPROPERTY(BlueprintReadOnly)
    bool bCurrentZoneObjectiveSatisfied = false;

    UPROPERTY(BlueprintReadOnly)
    bool bRunCompleted = false;

    UPROPERTY(BlueprintReadOnly)
    TSet<FName> DiscoveredRemanenceIds;
};

UCLASS()
class LITD2_API ULITD2RunDirectorSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    UPROPERTY(BlueprintAssignable, Category="LITD2|Run")
    FLITD2RunZoneEvent OnZoneStarted;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Run")
    FLITD2RunZoneEvent OnZoneCompleted;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Run")
    FLITD2RunBranchEvent OnBranchChosen;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Run")
    FLITD2RunRemanenceEvent OnRemanenceDiscovered;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Run")
    FLITD2RunBossPhaseEvent OnBossPhaseChanged;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Run")
    FLITD2RunSimpleEvent OnRunCompleted;

    UFUNCTION(BlueprintCallable, Category="LITD2|Run")
    bool StartSareiRun(FName OathId);

    UFUNCTION(BlueprintCallable, Category="LITD2|Run")
    bool CompleteCurrentZone();

    UFUNCTION(BlueprintCallable, Category="LITD2|Run")
    bool ChooseBranch(FName BranchId);

    UFUNCTION(BlueprintCallable, Category="LITD2|Run")
    void MarkCurrentZoneObjectiveSatisfied();

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Health")
    int32 ApplyCombatDamage(int32 DamageAmount);

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Health")
    bool ApplyTrauma(int32 Level, int32 LockedHealthAmount, int32 ImmediateDamage = 0);

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Health")
    int32 UseFountain();

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Health")
    bool UsePotion();

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Health")
    bool GrantContextualReplacementPotion();

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Remanence")
    bool DiscoverRemanence(FName EntryId);

    UFUNCTION(BlueprintCallable, Category="LITD2|Run|Boss")
    void ReportBossHealthPercent(float HealthPercent);

    UFUNCTION(BlueprintPure, Category="LITD2|Run")
    FLITD2RunRuntimeState GetRuntimeState() const { return State; }

    UFUNCTION(BlueprintPure, Category="LITD2|Run")
    FLITD2RunZoneDefinition GetCurrentZone() const;

    UFUNCTION(BlueprintPure, Category="LITD2|Run")
    int32 GetRecoverableMaxHealth() const;

private:
    TArray<FLITD2RunZoneDefinition> Zones;
    FLITD2RunRuntimeState State;
    int32 LastBossPhase = 0;

    bool LoadRunDefinition(const FString& RelativePath);
    bool CanCompleteCurrentZone() const;
    void EnterZone(int32 ZoneIndex);
    void ResetRuntime(FName OathId);
};
