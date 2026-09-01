#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "LITD2EncounterDirectorSubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_FourParams(FLITD2EncounterSpawnEvent, FName, ZoneId, FName, EnemyId, int32, Count, int32, WaveIndex);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FLITD2BossSpawnEvent, FName, ZoneId, FName, BossId);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FLITD2WaveEvent, FName, ZoneId, int32, WaveIndex);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FLITD2EncounterZoneEvent, FName, ZoneId);

USTRUCT(BlueprintType)
struct FLITD2EnemySpawnRequest
{
    GENERATED_BODY()

    UPROPERTY(BlueprintReadOnly)
    FName EnemyId = NAME_None;

    UPROPERTY(BlueprintReadOnly)
    int32 Count = 0;
};

/**
 * Dispatches data-driven spawn requests from the current Sarei zone.
 * Actual actors remain Blueprint/world responsibilities; this subsystem owns wave completion.
 */
UCLASS()
class LITD2_API ULITD2EncounterDirectorSubsystem : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    UPROPERTY(BlueprintAssignable, Category="LITD2|Encounter")
    FLITD2EncounterSpawnEvent OnEnemySpawnRequested;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Encounter")
    FLITD2BossSpawnEvent OnBossSpawnRequested;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Encounter")
    FLITD2WaveEvent OnWaveStarted;

    UPROPERTY(BlueprintAssignable, Category="LITD2|Encounter")
    FLITD2EncounterZoneEvent OnEncounterZoneCompleted;

    UFUNCTION(BlueprintCallable, Category="LITD2|Encounter")
    bool BeginZone(FName ZoneId, FName BranchId = NAME_None);

    UFUNCTION(BlueprintCallable, Category="LITD2|Encounter")
    bool ReportEnemyDefeated(FName EnemyId);

    UFUNCTION(BlueprintCallable, Category="LITD2|Encounter")
    bool ReportBossDefeated(FName BossId);

    UFUNCTION(BlueprintPure, Category="LITD2|Encounter")
    int32 GetRemainingEnemies() const { return RemainingEnemies; }

private:
    FName ActiveZoneId = NAME_None;
    FName ActiveBossId = NAME_None;
    TArray<TArray<FLITD2EnemySpawnRequest>> Waves;
    int32 CurrentWaveIndex = INDEX_NONE;
    int32 RemainingEnemies = 0;
    TMap<FName, int32> RemainingByEnemyId;

    bool LoadZone(FName ZoneId, FName BranchId);
    void StartWave(int32 WaveIndex);
    void FinishZone();
};
