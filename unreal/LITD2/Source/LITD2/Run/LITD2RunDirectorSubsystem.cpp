#include "Run/LITD2RunDirectorSubsystem.h"

#include "Dom/JsonObject.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Remanence/LITD2RemembranceSubsystem.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"

namespace
{
    bool ReadString(const TSharedPtr<FJsonObject>& Object, const TCHAR* Field, FString& Out)
    {
        return Object.IsValid() && Object->TryGetStringField(Field, Out);
    }
}

bool ULITD2RunDirectorSubsystem::StartSareiRun(FName OathId)
{
    Zones.Reset();
    if (!LoadRunDefinition(TEXT("Data/Runs/sarei_faubourgs_run.json")))
    {
        return false;
    }

    ResetRuntime(OathId);
    EnterZone(0);
    return true;
}

void ULITD2RunDirectorSubsystem::ResetRuntime(FName OathId)
{
    State = FLITD2RunRuntimeState();
    State.RunId = TEXT("SAREI_FAUBOURGS_01");
    State.SelectedOathId = OathId;
    State.PotionCapacity = 3;
    State.PotionCount = 3;
    State.MaxHealth = 1000;
    State.CurrentHealth = 1000;
    State.LockedHealth = 0;
    State.TraumaLevel = 0;
    State.CurrentZoneIndex = INDEX_NONE;
    State.bRunCompleted = false;
    LastBossPhase = 0;
}

bool ULITD2RunDirectorSubsystem::LoadRunDefinition(const FString& RelativePath)
{
    const FString AbsolutePath = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), RelativePath));
    FString JsonText;
    if (!FFileHelper::LoadFileToString(JsonText, *AbsolutePath))
    {
        UE_LOG(LogTemp, Error, TEXT("LITD2 RunDirector: cannot load %s"), *AbsolutePath);
        return false;
    }

    TSharedPtr<FJsonObject> Root;
    const TSharedRef<TJsonReader<>> Reader = TJsonReaderFactory<>::Create(JsonText);
    if (!FJsonSerializer::Deserialize(Reader, Root) || !Root.IsValid() || !Root->HasField(TEXT("zones")))
    {
        UE_LOG(LogTemp, Error, TEXT("LITD2 RunDirector: invalid run JSON %s"), *AbsolutePath);
        return false;
    }

    const TArray<TSharedPtr<FJsonValue>>& JsonZones = Root->GetArrayField(TEXT("zones"));
    for (const TSharedPtr<FJsonValue>& Value : JsonZones)
    {
        const TSharedPtr<FJsonObject> Object = Value.IsValid() ? Value->AsObject() : nullptr;
        if (!Object.IsValid())
        {
            continue;
        }

        FString ZoneId;
        FString Title;
        FString Type;
        if (!ReadString(Object, TEXT("zone_id"), ZoneId) || !ReadString(Object, TEXT("title"), Title) || !ReadString(Object, TEXT("type"), Type))
        {
            continue;
        }

        FLITD2RunZoneDefinition Zone;
        Zone.ZoneId = FName(*ZoneId);
        Zone.Title = FText::FromString(Title);
        Zone.Type = Type;

        FString BossId;
        if (ReadString(Object, TEXT("boss_id"), BossId))
        {
            Zone.BossId = FName(*BossId);
        }

        FString RemanenceId;
        if (ReadString(Object, TEXT("mandatory_remanence_id"), RemanenceId) || ReadString(Object, TEXT("remanence_id"), RemanenceId))
        {
            Zone.MandatoryRemanenceId = FName(*RemanenceId);
        }

        Zones.Add(MoveTemp(Zone));
    }

    return Zones.Num() == 9;
}

void ULITD2RunDirectorSubsystem::EnterZone(int32 ZoneIndex)
{
    if (!Zones.IsValidIndex(ZoneIndex))
    {
        State.bRunCompleted = true;
        OnRunCompleted.Broadcast();
        return;
    }

    State.CurrentZoneIndex = ZoneIndex;
    State.bCurrentZoneObjectiveSatisfied = false;
    const FLITD2RunZoneDefinition& Zone = Zones[ZoneIndex];

    // Preparation and non-combat conclusion zones are explicit but can be completed by UI/level logic.
    if (Zone.ZoneId == TEXT("Z0_PREP"))
    {
        State.bCurrentZoneObjectiveSatisfied = !State.SelectedOathId.IsNone();
    }

    OnZoneStarted.Broadcast(Zone.ZoneId, Zone.Title);
}

bool ULITD2RunDirectorSubsystem::CanCompleteCurrentZone() const
{
    if (!Zones.IsValidIndex(State.CurrentZoneIndex))
    {
        return false;
    }

    const FLITD2RunZoneDefinition& Zone = Zones[State.CurrentZoneIndex];
    if (Zone.ZoneId == TEXT("Z4_ASH_CROSSROADS") && State.SelectedBranchId.IsNone())
    {
        return false;
    }

    if (!Zone.MandatoryRemanenceId.IsNone() && !State.DiscoveredRemanenceIds.Contains(Zone.MandatoryRemanenceId))
    {
        return false;
    }

    return State.bCurrentZoneObjectiveSatisfied;
}

bool ULITD2RunDirectorSubsystem::CompleteCurrentZone()
{
    if (!CanCompleteCurrentZone())
    {
        return false;
    }

    const FLITD2RunZoneDefinition CompletedZone = Zones[State.CurrentZoneIndex];
    OnZoneCompleted.Broadcast(CompletedZone.ZoneId, CompletedZone.Title);

    const int32 NextIndex = State.CurrentZoneIndex + 1;
    if (NextIndex >= Zones.Num())
    {
        State.bRunCompleted = true;
        OnRunCompleted.Broadcast();
        return true;
    }

    EnterZone(NextIndex);
    return true;
}

bool ULITD2RunDirectorSubsystem::ChooseBranch(FName BranchId)
{
    if (!Zones.IsValidIndex(State.CurrentZoneIndex) || Zones[State.CurrentZoneIndex].ZoneId != TEXT("Z4_ASH_CROSSROADS"))
    {
        return false;
    }

    if (BranchId != TEXT("CONVOY_YARD") && BranchId != TEXT("GLASSMAKERS_STREET"))
    {
        return false;
    }

    State.SelectedBranchId = BranchId;
    OnBranchChosen.Broadcast(BranchId);
    return true;
}

void ULITD2RunDirectorSubsystem::MarkCurrentZoneObjectiveSatisfied()
{
    State.bCurrentZoneObjectiveSatisfied = true;
}

int32 ULITD2RunDirectorSubsystem::GetRecoverableMaxHealth() const
{
    return FMath::Max(1, State.MaxHealth - State.LockedHealth);
}

bool ULITD2RunDirectorSubsystem::ApplyTrauma(int32 Level, int32 LockedHealthAmount, int32 ImmediateDamage)
{
    if (Level <= 0 || LockedHealthAmount <= 0)
    {
        return false;
    }

    State.TraumaLevel = FMath::Clamp(FMath::Max(State.TraumaLevel, Level), 0, 3);
    State.LockedHealth = FMath::Clamp(State.LockedHealth + LockedHealthAmount, 0, FMath::FloorToInt(State.MaxHealth * 0.45f));
    State.CurrentHealth = FMath::Clamp(State.CurrentHealth - FMath::Max(0, ImmediateDamage), 0, GetRecoverableMaxHealth());
    return true;
}

int32 ULITD2RunDirectorSubsystem::UseFountain()
{
    const int32 Before = State.CurrentHealth;
    State.CurrentHealth = GetRecoverableMaxHealth();
    return State.CurrentHealth - Before;
}

bool ULITD2RunDirectorSubsystem::UsePotion()
{
    if (State.PotionCount <= 0)
    {
        return false;
    }

    --State.PotionCount;
    State.TraumaLevel = 0;
    State.LockedHealth = 0;
    State.CurrentHealth = State.MaxHealth;
    return true;
}

bool ULITD2RunDirectorSubsystem::GrantContextualReplacementPotion()
{
    if (State.PotionCount >= State.PotionCapacity)
    {
        return false;
    }

    ++State.PotionCount;
    return true;
}

bool ULITD2RunDirectorSubsystem::DiscoverRemanence(FName EntryId)
{
    if (EntryId.IsNone() || State.DiscoveredRemanenceIds.Contains(EntryId))
    {
        return false;
    }

    State.DiscoveredRemanenceIds.Add(EntryId);

    if (UGameInstance* GameInstance = GetGameInstance())
    {
        if (ULITD2RemembranceSubsystem* Archives = GameInstance->GetSubsystem<ULITD2RemembranceSubsystem>())
        {
            Archives->SetEntryState(EntryId, ELITD2RemembranceDiscoveryState::Trace);
            Archives->SaveArchives();
        }
    }

    OnRemanenceDiscovered.Broadcast(EntryId);
    return true;
}

void ULITD2RunDirectorSubsystem::ReportBossHealthPercent(float HealthPercent)
{
    if (!Zones.IsValidIndex(State.CurrentZoneIndex) || Zones[State.CurrentZoneIndex].ZoneId != TEXT("Z7_SOUTH_BARRICADE"))
    {
        return;
    }

    const float Clamped = FMath::Clamp(HealthPercent, 0.0f, 100.0f);
    int32 NewPhase = 1;
    if (Clamped <= 25.0f)
    {
        NewPhase = 3;
    }
    else if (Clamped <= 60.0f)
    {
        NewPhase = 2;
    }

    if (NewPhase != LastBossPhase)
    {
        LastBossPhase = NewPhase;
        OnBossPhaseChanged.Broadcast(NewPhase);
    }

    if (Clamped <= 0.0f)
    {
        State.bCurrentZoneObjectiveSatisfied = true;
    }
}

FLITD2RunZoneDefinition ULITD2RunDirectorSubsystem::GetCurrentZone() const
{
    return Zones.IsValidIndex(State.CurrentZoneIndex) ? Zones[State.CurrentZoneIndex] : FLITD2RunZoneDefinition();
}
