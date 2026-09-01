#include "Run/LITD2EncounterDirectorSubsystem.h"

#include "Dom/JsonObject.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Run/LITD2RunDirectorSubsystem.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

namespace
{
    bool ParseSpawnArray(const TArray<TSharedPtr<FJsonValue>>& Values, TArray<FLITD2EnemySpawnRequest>& Out)
    {
        Out.Reset();
        for (const TSharedPtr<FJsonValue>& Value : Values)
        {
            const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
            if (!Object.IsValid())
            {
                continue;
            }

            FString EnemyId;
            double Count = 0.0;
            if (!Object->TryGetStringField(TEXT("enemy_id"), EnemyId) || !Object->TryGetNumberField(TEXT("count"), Count))
            {
                continue;
            }

            FLITD2EnemySpawnRequest Request;
            Request.EnemyId = FName(*EnemyId);
            Request.Count = FMath::Max(0, FMath::RoundToInt(Count));
            if (Request.Count > 0)
            {
                Out.Add(Request);
            }
        }
        return Out.Num() > 0;
    }
}

bool ULITD2EncounterDirectorSubsystem::BeginZone(FName ZoneId, FName BranchId)
{
    ActiveZoneId = ZoneId;
    ActiveBossId = NAME_None;
    Waves.Reset();
    CurrentWaveIndex = INDEX_NONE;
    RemainingEnemies = 0;
    RemainingByEnemyId.Reset();

    if (!LoadZone(ZoneId, BranchId))
    {
        return false;
    }

    if (!ActiveBossId.IsNone())
    {
        OnBossSpawnRequested.Broadcast(ActiveZoneId, ActiveBossId);
        return true;
    }

    if (Waves.Num() > 0)
    {
        StartWave(0);
        return true;
    }

    FinishZone();
    return true;
}

bool ULITD2EncounterDirectorSubsystem::LoadZone(FName ZoneId, FName BranchId)
{
    const FString Path = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), TEXT("Data/Runs/sarei_faubourgs_run.json")));
    FString JsonText;
    if (!FFileHelper::LoadFileToString(JsonText, *Path))
    {
        return false;
    }

    TSharedPtr<FJsonObject> Root;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonText);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid())
    {
        return false;
    }

    const TArray<TSharedPtr<FJsonValue>>& JsonZones = Root->GetArrayField(TEXT("zones"));
    for (const TSharedPtr<FJsonValue>& ZoneValue : JsonZones)
    {
        const TSharedPtr<FJsonObject> ZoneObject = ZoneValue.IsValid() ? ZoneValue->AsObject() : nullptr;
        if (!ZoneObject.IsValid())
        {
            continue;
        }

        FString JsonZoneId;
        if (!ZoneObject->TryGetStringField(TEXT("zone_id"), JsonZoneId) || FName(*JsonZoneId) != ZoneId)
        {
            continue;
        }

        FString BossId;
        if (ZoneObject->TryGetStringField(TEXT("boss_id"), BossId))
        {
            ActiveBossId = FName(*BossId);
            return true;
        }

        if (ZoneObject->HasField(TEXT("waves")))
        {
            for (const TSharedPtr<FJsonValue>& WaveValue : ZoneObject->GetArrayField(TEXT("waves")))
            {
                TArray<FLITD2EnemySpawnRequest> Wave;
                if (WaveValue.IsValid() && ParseSpawnArray(WaveValue->AsArray(), Wave))
                {
                    Waves.Add(MoveTemp(Wave));
                }
            }
            return Waves.Num() > 0;
        }

        if (ZoneObject->HasField(TEXT("branches")))
        {
            for (const TSharedPtr<FJsonValue>& BranchValue : ZoneObject->GetArrayField(TEXT("branches")))
            {
                const TSharedPtr<FJsonObject> BranchObject = BranchValue.IsValid() ? BranchValue->AsObject() : nullptr;
                FString JsonBranchId;
                if (!BranchObject.IsValid() || !BranchObject->TryGetStringField(TEXT("branch_id"), JsonBranchId) || FName(*JsonBranchId) != BranchId)
                {
                    continue;
                }

                TArray<FLITD2EnemySpawnRequest> Wave;
                if (ParseSpawnArray(BranchObject->GetArrayField(TEXT("encounters")), Wave))
                {
                    Waves.Add(MoveTemp(Wave));
                }
                return Waves.Num() > 0;
            }
            return false;
        }

        if (ZoneObject->HasField(TEXT("encounters")))
        {
            TArray<FLITD2EnemySpawnRequest> Wave;
            if (ParseSpawnArray(ZoneObject->GetArrayField(TEXT("encounters")), Wave))
            {
                Waves.Add(MoveTemp(Wave));
            }
            return Waves.Num() > 0;
        }

        return true;
    }

    return false;
}

void ULITD2EncounterDirectorSubsystem::StartWave(int32 WaveIndex)
{
    if (!Waves.IsValidIndex(WaveIndex))
    {
        FinishZone();
        return;
    }

    CurrentWaveIndex = WaveIndex;
    RemainingEnemies = 0;
    RemainingByEnemyId.Reset();
    OnWaveStarted.Broadcast(ActiveZoneId, WaveIndex);

    for (const FLITD2EnemySpawnRequest& Request : Waves[WaveIndex])
    {
        RemainingEnemies += Request.Count;
        RemainingByEnemyId.FindOrAdd(Request.EnemyId) += Request.Count;
        OnEnemySpawnRequested.Broadcast(ActiveZoneId, Request.EnemyId, Request.Count, WaveIndex);
    }
}

bool ULITD2EncounterDirectorSubsystem::ReportEnemyDefeated(FName EnemyId)
{
    int32* RemainingForType = RemainingByEnemyId.Find(EnemyId);
    if (!RemainingForType || *RemainingForType <= 0 || RemainingEnemies <= 0)
    {
        return false;
    }

    --(*RemainingForType);
    --RemainingEnemies;

    if (RemainingEnemies <= 0)
    {
        const int32 NextWave = CurrentWaveIndex + 1;
        if (Waves.IsValidIndex(NextWave))
        {
            StartWave(NextWave);
        }
        else
        {
            FinishZone();
        }
    }
    return true;
}

bool ULITD2EncounterDirectorSubsystem::ReportBossDefeated(FName BossId)
{
    if (ActiveBossId.IsNone() || BossId != ActiveBossId)
    {
        return false;
    }

    if (UGameInstance* GameInstance = GetGameInstance())
    {
        if (ULITD2RunDirectorSubsystem* RunDirector = GameInstance->GetSubsystem<ULITD2RunDirectorSubsystem>())
        {
            if (ActiveZoneId == TEXT("Z7_SOUTH_BARRICADE"))
            {
                RunDirector->ReportBossHealthPercent(0.0f);
            }
            else
            {
                RunDirector->MarkCurrentZoneObjectiveSatisfied();
            }
        }
    }

    OnEncounterZoneCompleted.Broadcast(ActiveZoneId);
    ActiveBossId = NAME_None;
    return true;
}

void ULITD2EncounterDirectorSubsystem::FinishZone()
{
    if (UGameInstance* GameInstance = GetGameInstance())
    {
        if (ULITD2RunDirectorSubsystem* RunDirector = GameInstance->GetSubsystem<ULITD2RunDirectorSubsystem>())
        {
            RunDirector->MarkCurrentZoneObjectiveSatisfied();
        }
    }
    OnEncounterZoneCompleted.Broadcast(ActiveZoneId);
}
