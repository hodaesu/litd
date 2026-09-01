#include "Remanence/LITD2RemembranceSubsystem.h"

#include "Kismet/GameplayStatics.h"
#include "Remanence/LITD2RemembranceSaveGame.h"

const FString ULITD2RemembranceSubsystem::SaveSlotName(TEXT("LITD2_RemembranceArchives"));

ULITD2RemembranceSaveGame* ULITD2RemembranceSubsystem::EnsureState()
{
    if (!RuntimeState)
    {
        RuntimeState = Cast<ULITD2RemembranceSaveGame>(
            UGameplayStatics::CreateSaveGameObject(ULITD2RemembranceSaveGame::StaticClass()));
    }
    return RuntimeState;
}

const ULITD2RemembranceSaveGame* ULITD2RemembranceSubsystem::GetState() const
{
    return RuntimeState;
}

void ULITD2RemembranceSubsystem::SetEntryState(FName EntryId, ELITD2RemembranceDiscoveryState NewState)
{
    if (EntryId.IsNone())
    {
        return;
    }

    ULITD2RemembranceSaveGame* State = EnsureState();
    const ELITD2RemembranceDiscoveryState Previous = GetEntryState(EntryId);
    if (Previous == NewState)
    {
        return;
    }

    State->EntryStates.FindOrAdd(EntryId) = NewState;
    OnEntryChanged.Broadcast(EntryId, NewState);
}

ELITD2RemembranceDiscoveryState ULITD2RemembranceSubsystem::GetEntryState(FName EntryId) const
{
    if (const ULITD2RemembranceSaveGame* State = GetState())
    {
        if (const ELITD2RemembranceDiscoveryState* Found = State->EntryStates.Find(EntryId))
        {
            return *Found;
        }
    }
    return ELITD2RemembranceDiscoveryState::Unknown;
}

void ULITD2RemembranceSubsystem::DiscoverSource(FName SourceId)
{
    if (!SourceId.IsNone())
    {
        EnsureState()->DiscoveredSourceIds.Add(SourceId);
    }
}

bool ULITD2RemembranceSubsystem::HasDiscoveredSource(FName SourceId) const
{
    const ULITD2RemembranceSaveGame* State = GetState();
    return State && State->DiscoveredSourceIds.Contains(SourceId);
}

bool ULITD2RemembranceSubsystem::IsKnownEntry(FName EntryId) const
{
    return GetEntryState(EntryId) != ELITD2RemembranceDiscoveryState::Unknown;
}

bool ULITD2RemembranceSubsystem::IsRequirementGroupSatisfied(const FLITD2KnowledgeRequirementGroup& Group) const
{
    int32 MatchCount = 0;

    for (const FName EntryId : Group.AnyOfEntryIds)
    {
        if (IsKnownEntry(EntryId))
        {
            ++MatchCount;
        }
    }

    for (const FName SourceId : Group.AnyOfSourceIds)
    {
        if (HasDiscoveredSource(SourceId))
        {
            ++MatchCount;
        }
    }

    return MatchCount >= FMath::Max(1, Group.MinimumMatches);
}

bool ULITD2RemembranceSubsystem::CanReconstruct(const ULITD2RemembranceReconstruction* Reconstruction) const
{
    if (!Reconstruction || Reconstruction->ReconstructionId.IsNone() ||
        IsReconstructionCompleted(Reconstruction->ReconstructionId))
    {
        return false;
    }

    for (const FName RequiredEntryId : Reconstruction->RequiredEntryIds)
    {
        if (!IsKnownEntry(RequiredEntryId))
        {
            return false;
        }
    }

    for (const FLITD2KnowledgeRequirementGroup& Group : Reconstruction->AlternativeRequirementGroups)
    {
        if (!IsRequirementGroupSatisfied(Group))
        {
            return false;
        }
    }

    return true;
}

void ULITD2RemembranceSubsystem::ApplyUnlock(const FLITD2GameplayUnlock& Unlock)
{
    if (Unlock.UnlockId.IsNone())
    {
        return;
    }

    ULITD2RemembranceSaveGame* State = EnsureState();
    State->UnlockedIds.Add(Unlock.UnlockId);

    if (Unlock.IntegerValue != 0 || Unlock.Type == ELITD2UnlockType::LogisticsCapacity)
    {
        int32& StoredValue = State->IntegerUnlockValues.FindOrAdd(Unlock.UnlockId);
        StoredValue = FMath::Max(StoredValue, Unlock.IntegerValue);
    }
}

bool ULITD2RemembranceSubsystem::ApplyReconstruction(const ULITD2RemembranceReconstruction* Reconstruction)
{
    if (!CanReconstruct(Reconstruction))
    {
        return false;
    }

    ULITD2RemembranceSaveGame* State = EnsureState();
    State->CompletedReconstructionIds.Add(Reconstruction->ReconstructionId);

    if (!Reconstruction->ResultEntryId.IsNone())
    {
        SetEntryState(Reconstruction->ResultEntryId, ELITD2RemembranceDiscoveryState::Reconstructed);
    }

    for (const FLITD2GameplayUnlock& Unlock : Reconstruction->Unlocks)
    {
        ApplyUnlock(Unlock);
    }

    OnReconstructionCompleted.Broadcast(Reconstruction->ReconstructionId);
    return true;
}

bool ULITD2RemembranceSubsystem::IsReconstructionCompleted(FName ReconstructionId) const
{
    const ULITD2RemembranceSaveGame* State = GetState();
    return State && State->CompletedReconstructionIds.Contains(ReconstructionId);
}

bool ULITD2RemembranceSubsystem::IsUnlocked(FName UnlockId) const
{
    const ULITD2RemembranceSaveGame* State = GetState();
    return State && State->UnlockedIds.Contains(UnlockId);
}

int32 ULITD2RemembranceSubsystem::GetIntegerUnlockValue(FName UnlockId, int32 DefaultValue) const
{
    if (const ULITD2RemembranceSaveGame* State = GetState())
    {
        if (const int32* Found = State->IntegerUnlockValues.Find(UnlockId))
        {
            return *Found;
        }
    }
    return DefaultValue;
}

bool ULITD2RemembranceSubsystem::SaveArchives()
{
    ULITD2RemembranceSaveGame* State = EnsureState();
    return State && UGameplayStatics::SaveGameToSlot(State, SaveSlotName, 0);
}

bool ULITD2RemembranceSubsystem::LoadArchives()
{
    if (!UGameplayStatics::DoesSaveGameExist(SaveSlotName, 0))
    {
        EnsureState();
        return false;
    }

    RuntimeState = Cast<ULITD2RemembranceSaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlotName, 0));
    return RuntimeState != nullptr;
}
